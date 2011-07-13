//  BWDB.m
//  Rssder
//
//  Created by yangfei on 11-6-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import "BWDB.h"

@implementation BWDB

@synthesize tableName;

#pragma mark -
#pragma mark Object Management

- (void)dealloc {
    // NSLog(@"%s", __FUNCTION__);
    [self closeDB];
    [super dealloc];
}

// if you're not using the CRUD functions, you don't need a table name
- (BWDB *) initWithDBFilename:(NSString *)fn {
    // NSLog(@"%s", __FUNCTION__);
    if ((self = [super init])) {
        databaseFileName = fn;
        tableName = nil;
        [self openDB];
    }
    return self;
}

- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn {
    // NSLog(@"%s", __FUNCTION__);
    if ((self = [super init])) {
        databaseFileName = fn;
        tableName = tn;
        [self openDB];
    }
    return self;
}

- (void) openDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) return;
    filemanager = [[NSFileManager alloc] init];
    NSString * dbpath = [self getDBPath];

    if (![filemanager fileExistsAtPath:dbpath]) {
        // try to copy from default, if we have it
        NSString * defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseFileName];
        if ([filemanager fileExistsAtPath:defaultDBPath]) {
            // NSLog(@"copy default DB");
            [filemanager copyItemAtPath:defaultDBPath toPath:dbpath error:NULL];
        }
    }
    if (sqlite3_open([dbpath UTF8String], &database) != SQLITE_OK) {
        NSAssert1(0, @"Error: initializeDatabase: could not open database (%s)", sqlite3_errmsg(database));
    }
    [filemanager release];
    filemanager = nil;
}

- (void) closeDB {
    // NSLog(@"%s", __FUNCTION__);
    if (database) sqlite3_close(database);
    if (filemanager) [filemanager release];
    database = NULL;
    filemanager = nil;
}

- (NSString *) getVersion {
    return BWDB_VERSION;
}

- (NSString *) getDBPath {
    // NSLog(@"%s", __FUNCTION__);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:databaseFileName];
}

// iteration in ObjC is called "fast enumeration"
// this is a simple implementation
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    if (*enumRows = [self getPreparedRow]) {
        state->itemsPtr = enumRows;
        state->state = 0;   // not used, customarily set to zero
        state->mutationsPtr = (unsigned long *) self;   // also not used, required by the interface
        return 1;
    } else {
        return 0;
    }
}

#pragma mark -
#pragma mark SQL Queries

// doQuery:query,...
// executes a non-select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// Return value is the number of affect rows
- (NSNumber *) doQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);

    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery arguments:args];
    if (statement == NULL) return [NSNumber numberWithInt:0];

    va_end(args);
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return [NSNumber numberWithInt: sqlite3_changes(database)];
    } else {
        NSLog(@"doQuery: sqlite3_finalize failed (%s)", sqlite3_errmsg(database));
        return [NSNumber numberWithInt:0];
    }
}

// prepareQuery:query,...
// prepares a select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// use getRow or getValue to get results
- (void) prepareQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);

    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery arguments:args];
    if (statement == NULL) return;
    va_end(args);
}

// prepareQuery:query,...
// executes a select query on the SQLite database
// uses SQLbind to bind the variadic parameters
// Returns NSArray of NSDictionary objects
- (BWDB *) getQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery arguments:args];
    if (statement == NULL) return nil;
    va_end(args);
    return self;
}

- (id) valueFromQuery:(NSString *) query, ... {
    // NSLog(@"%s: %@", __FUNCTION__, query);
    va_list args;
    va_start(args, query);
    const char *cQuery = [query UTF8String];
    [self bindSQL:cQuery arguments:args];
    if (statement == NULL) return nil;
    va_end(args);
    return [self getPreparedValue];
}


// bindSQL:arguments
// binds variadic arguments to the SQL query. 
// cQuery is a C string, args is a variadic list of ObjC objects
// objects in variadic list are tested for type
// see SQLquery for how to call this
- (void) bindSQL:(const char *) cQuery arguments:(va_list)args {
    // NSLog(@"%s: %s", __FUNCTION__, cQuery);
    int param_count;
    
    // preparing the query here allows SQLite to determine
    // the number of required parameters
    if (sqlite3_prepare_v2(database, cQuery, -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"bindSQL: could not prepare statement (%s)", sqlite3_errmsg(database));
        statement = NULL;
        return;
    }
    
    if ((param_count = sqlite3_bind_parameter_count(statement))) {
        for (int i = 0; i < param_count; i++) {
            id o = va_arg(args, id);

            // determine the type of the argument
            if (o == nil) {
                sqlite3_bind_null(statement, i + 1);
            } else if ([o respondsToSelector:@selector(objCType)]) {
                if (strchr("islISLB", *[o objCType])) { // integer
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
                } else if (strchr("fd", *[o objCType])) {   // double
                    sqlite3_bind_double(statement, i + 1, [o doubleValue]);
                } else {    // unhandled types
                    NSLog(@"bindSQL: Unhandled objCType: %s", [o objCType]);
                    statement = NULL;
                    return;
                }
            } else if ([o respondsToSelector:@selector(UTF8String)]) { // string
                sqlite3_bind_text(statement, i + 1, [o UTF8String], -1, SQLITE_TRANSIENT);
            } else {    // unhhandled type
                NSLog(@"bindSQL: Unhandled parameter type: %@", [o class]);
                statement = NULL;
                return;
            }
        }
    }
    
    va_end(args);
    return;
}

#pragma mark -
#pragma mark CRUD Methods

- (NSNumber *) insertRow:(NSDictionary *) record {
    // NSLog(@"%s", __FUNCTION__);
    int dictSize = [record count];
    
    // the values array is used as the argument list for bindSQL
    id keys[dictSize];  // not used, just a side-effect of getObjects:andKeys
    id values[dictSize];
    [record getObjects:values andKeys:keys];    // convenient for the C array
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:dictSize];
    for (int i = 0; i < dictSize; i++)  // array of ? markers for placeholders in query
        [placeHoldersArray addObject: [NSString stringWithString:@"?"]];
    
    NSString * query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@","],
                        [placeHoldersArray componentsJoinedByString:@","]];
    
    [self bindSQL:[query UTF8String] arguments:(va_list)values];
    sqlite3_step(statement);
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        return [self lastInsertId];
    } else {
        NSLog(@"doQuery: sqlite3_finalize failed (%s)", sqlite3_errmsg(database));
        return [NSNumber numberWithInt:0];
    }
}

- (void) updateRow:(NSDictionary *) record:(NSNumber *) rowID {
    // NSLog(@"%s", __FUNCTION__);
    int dictSize = [record count];
    
    // the values array is used as the argument list for bindSQL
    id keys[dictSize];  // not used, just a side-effect of getObjects:andKeys
    id values[dictSize + 1];
    [record getObjects:values andKeys:keys];    // convenient for the C array
    values[dictSize] = rowID;
    
    NSString * query = [NSString stringWithFormat:@"update %@ set %@ = ? where id = ?",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@" = ?, "]];
    
    [self bindSQL:[query UTF8String] arguments:(va_list)values];
    sqlite3_step(statement);
    sqlite3_finalize(statement);
}

- (void) deleteRow:(NSNumber *) rowID {
    // NSLog(@"%s", __FUNCTION__);
    
    NSString * query = [NSString stringWithFormat:@"delete from %@ where id = ?", tableName];
    [self doQuery:query, rowID];
}

- (NSDictionary *) getRow: (NSNumber *) rowID {
    NSString * query = [NSString stringWithFormat:@"select * from %@ where id = ?", tableName];
    [self prepareQuery:query, rowID];
    return [self getPreparedRow];
}

- (NSNumber *) countRows {
    return [self valueFromQuery:[NSString stringWithFormat:@"select count(*) from %@", tableName]];
}

#pragma mark -
#pragma mark Raw results

- (NSDictionary *) getPreparedRow {
    // NSLog(@"%s", __FUNCTION__);
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count >= 1) {
            NSMutableDictionary * dRow = [NSMutableDictionary dictionaryWithCapacity:1];
            for(int i = 0; i < col_count; i++) {
                // can't use NULL with stringWithUTF8String (bw 1.0.5)
                const char * sqliteColName = sqlite3_column_name(statement, i);
                if(sqliteColName) {
                    NSString * columnName = [NSString stringWithUTF8String:sqliteColName];
                    id o = [self columnValue:i];
                    if (o != nil) [dRow setObject:o forKey:columnName];
                    else {
                        NSLog(@"getPreparedRow: columnValue returned nil (%s)", sqlite3_errmsg(database));
                        return nil;
                    }
                } else {
                    NSLog(@"getPreparedRow: sqlite3_column_name returned NULL (%s)", sqlite3_errmsg(database));
                    return nil;
                }
            }
            return dRow;
        }
    } else {    // rc != SQLITE_ROW
        NSLog(@"getPreparedRow: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
    return nil;
}

// returns one value from the first column of the query
- (id) getPreparedValue {
    // NSLog(@"%s", __FUNCTION__);
    int rc = sqlite3_step(statement);
    if (rc == SQLITE_DONE) {
        sqlite3_finalize(statement);
        return nil;
    } else  if (rc == SQLITE_ROW) {
        int col_count = sqlite3_column_count(statement);
        if (col_count < 1) return nil;  // shouldn't really ever happen
        id o = [self columnValue:0];
        sqlite3_finalize(statement);
        return o;
    } else {    // rc == SQLITE_ROW
        NSLog(@"valueFromPreparedQuery: could not get row: %s", sqlite3_errmsg(database));
        return nil;
    }
}

#pragma mark -
#pragma mark Utility Methods

- (id) columnValue:(int) columnIndex {
    // NSLog(@"%s columnIndex: %d", __FUNCTION__, columnIndex);
    id o = nil;
    switch(sqlite3_column_type(statement, columnIndex)) {
        case SQLITE_INTEGER:
            o = [NSNumber numberWithInt:sqlite3_column_int(statement, columnIndex)];
            break;
        case SQLITE_FLOAT:
            o = [NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)];
            break;
        case SQLITE_TEXT:
            o = [NSString stringWithUTF8String:(const char *) sqlite3_column_text(statement, columnIndex)];
            break;
        case SQLITE_BLOB:
            o = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
            break;
        case SQLITE_NULL:
            o = [NSNull null];
            break;
    }
    return o;
}

- (NSNumber *) lastInsertId {
    return [NSNumber numberWithInt: sqlite3_last_insert_rowid(database)];
}

@end
