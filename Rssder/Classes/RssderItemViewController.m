//
//  RssderItemViewController.m
//  Rssder
//
//  Created by yangfei on 11-6-29.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "RssderItemViewController.h"


@implementation RssderItemViewController

@synthesize rssDB, feedID, feedRecord, itemRecord, itemRowIDs;
@synthesize rssConnection, rssData;
@synthesize currentParseBatch, currentParsedCharacterData, currentItemObject, currentFeedObject;

#pragma mark Constants

// Dictionary keys
static NSString * const kItemFeedIDKey = @"feedID";
static NSString * const kItemUrlKey = @"url";
static NSString * const kItemTitleKey = @"title";
static NSString * const kItemDescKey = @"desc";
static NSString * const kItemPubDateKey = @"pubdateSQLString";
static NSString * const kDBItemFeedIDKey = @"feed_id";
static NSString * const kDBItemUrlKey = @"url";
static NSString * const kDBItemTitleKey = @"title";
static NSString * const kDBItemDescKey = @"desc";
static NSString * const kDBItemPubDateKey = @"pubdate";
static NSString * const kDBFeedTitleKey = @"title";
static NSString * const kDBFeedDescKey = @"desc";

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadRSSFeed];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.feedRecord = [rssDB getFeedRow:self.feedID];
    self.title = [feedRecord objectForKey:@"title"];
    self.tableView.rowHeight = 55.0;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // NSLog(@"%s", __FUNCTION__);
    self.itemRowIDs = [rssDB getItemIDs:feedID];
    return [itemRowIDs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ItemCell";
    
    // set up the cell with the subtitle style
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Show the title in the cell
    NSNumber *itemID = [self.itemRowIDs objectAtIndex:indexPath.row];
    NSDictionary * thisFeedItem = [rssDB getItemRow:itemID];
    
    // Clever variable font size trick
    CGFloat systemFontSize = [UIFont labelFontSize];
    CGFloat headFontSize = systemFontSize * .9;
    CGFloat smallFontSize = systemFontSize * .8;
    CGFloat widthOfCell = [tableView rectForRowAtIndexPath:indexPath].size.width - 40.0;
    
    NSString * itemText = [thisFeedItem objectForKey:kDBItemTitleKey];
    if (itemText) {
        [cell.textLabel setNumberOfLines:2];
        if ([itemText sizeWithFont:[UIFont boldSystemFontOfSize:headFontSize]].width > widthOfCell)
            [cell.textLabel setFont:[UIFont boldSystemFontOfSize:smallFontSize]];
        else
            [cell.textLabel setFont:[UIFont boldSystemFontOfSize:headFontSize]];
        
        [cell.textLabel setText:itemText];
    }
    
    // Format the date -- this goes in the detailTextLabel property, which is the "subtitle" of the cell
    [cell.detailTextLabel setFont:[UIFont systemFontOfSize:smallFontSize]];
    [cell.detailTextLabel setText:
     [self dateToLocalizedString:[self SQLDateToDate:[thisFeedItem valueForKey:kDBItemPubDateKey]]]
     ];
    
    return cell;
}

// User selected a row in the table view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"%s: %d", __FUNCTION__, indexPath.row);
    self.itemRecord = [rssDB getItemRow:[self.itemRowIDs objectAtIndex:indexPath.row]];
    
    // set up the web view, and push it onto the display
    RssderWebViewController *webView = [[RssderWebViewController alloc] initWithNibName:@"RssderWebViewController" bundle:nil];
    webView.feedItem = self.itemRecord;
    [[self navigationController] pushViewController:webView animated:YES];
    [webView release];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.itemRowIDs = nil;
}

- (void)dealloc {
    [super dealloc];
    if(feedRecord) [feedRecord release];
}

#pragma mark -
#pragma mark Support for shake gesture

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self resignFirstResponder];
    [super viewWillDisappear:animated];
}

-(BOOL)canBecomeFirstResponder
{
    return YES;
}

-(BOOL)canResignFirstResponder
{
    return YES;
}

-(void) motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        // NSLog(@"got a shake event");
        [self loadRSSFeed];
    }
}

#pragma mark -
#pragma mark Support methods

- (void) loadRSSFeed {
    self.feedRecord = [rssDB getFeedRow:self.feedID];
    NSURLRequest *rssURLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[feedRecord objectForKey:@"url"]]];
    self.rssConnection = [[[NSURLConnection alloc] initWithRequest:rssURLRequest delegate:self] autorelease];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSAssert(self.rssConnection != nil, @"Could not create URL connection.");
}

// --> This method runs in the secondary thread <-- 
// This calls the parser
- (void)parseRSSData:(NSData *)data {
    // NSLog(@"%s", __FUNCTION__);
    // You must create an autorelease pool for all secondary threads.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    self.currentParseBatch = [NSMutableArray array];
    self.currentParsedCharacterData = [NSMutableString string];
    parsedItemsCounter = 0;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];
    
    // depending on the total number of items parsed, the last batch might not have been a "full" batch, and thus
    // not been part of the regular batch transfer. So, we check the count of the array and, if necessary, send it to the main thread.
    if ([self.currentParseBatch count] > 0) {
        [self performSelectorOnMainThread:@selector(updateDBWithItems:) withObject:self.currentParseBatch waitUntilDone:NO];
    }
    self.currentParseBatch = nil;
    self.currentItemObject = nil;
    self.currentFeedObject = nil;
    self.currentParsedCharacterData = nil;
    [parser release];        
    [pool release];
}

// updateDBWithItems:
// --> This method runs in the main thread <--
// This is called from the parser thread with batches of parsed objects. 
- (void)updateDBWithItems:(NSArray *)items {
    // NSLog(@"updateDBWithItems (%d)", [items count]);
    for ( NSDictionary * item in items ) { // add rows to the item table
        [rssDB addItemRow:[NSDictionary dictionaryWithObjectsAndKeys:
                           [item valueForKey:kItemFeedIDKey], kDBItemFeedIDKey,
                           [item valueForKey:kItemUrlKey], kDBItemUrlKey,
                           trimString(flattenHTML([item valueForKey:kItemTitleKey])), kDBItemTitleKey,
                           trimString(flattenHTML([item valueForKey:kItemDescKey])), kDBItemDescKey,
                           [item valueForKey:kItemPubDateKey], kDBItemPubDateKey,
                           nil]];
    }
    self.itemRowIDs = [rssDB getItemIDs:self.feedID];
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // NSLog(@"%s %@", __FUNCTION__, [response MIMEType]);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    if (!rssData) rssData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // NSLog(@"%s (length: %d)", __FUNCTION__, [data length]);
    [self.rssData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // NSLog(@"%s", __FUNCTION__);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;   
    self.rssConnection = nil;
    
    // Spawn a thread to parse the RSS feed so that the UI is not blocked while parsing.
    // IMPORTANT! - Don't access UIKit objects on secondary threads.
    // NSLog(@"have data: %d bytes", [rssData length]);
    [NSThread detachNewThreadSelector:@selector(parseRSSData:) toTarget:self withObject:rssData];
    
    // rssData will be retained by the thread until parseRSSData: has finished executing, so we no longer need
    // a reference to it in the main thread.
    self.rssData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // NSLog(@"%s", __FUNCTION__);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if ([error code] == kCFURLErrorNotConnectedToInternet) {
        // if we can identify the error, we can present a more precise message to the user.
        NSDictionary *userInfo =
        [NSDictionary dictionaryWithObject:NSLocalizedString(@"No Connection Error", @"Not connected to the Internet.")
                                    forKey:NSLocalizedDescriptionKey];
        NSError *noConnectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:userInfo];
        [self handleError:noConnectionError];
    } else {
        // otherwise handle the error generically
        [self handleError:error];
    }
    self.rssConnection = nil;
}

#pragma -
#pragma mark Parser constants

// Limit the number of parsed items to 50.
static NSUInteger const kMaximumNumberOfItemsToParse = 50;

// Number of items in a parse batch
static NSUInteger const kSizeOfItemsBatch = 10;

// Reduce potential parsing errors by using string constants declared in a single place.
static NSString * const kChannelElementName = @"channel";
static NSString * const kItemElementName = @"item";
static NSString * const kDescriptionElementName = @"description";
static NSString * const kLinkElementName = @"link";
static NSString * const kTitleElementName = @"title";
static NSString * const kUpdatedElementName = @"pubDate";
static NSString * const kDCDateElementName = @"dc:date";

#pragma mark -
#pragma mark NSXMLParser delegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    // NSLog(@"%s %@", __FUNCTION__, elementName);
    
    NSArray * containerElements = [NSArray arrayWithObjects:
                                   kLinkElementName, kTitleElementName, kDescriptionElementName,
                                   kUpdatedElementName, kDCDateElementName, nil];
    
    // If the number of parsed items is greater than kMaximumNumberOfItemsToParse, abort the parse.
    if (parsedItemsCounter >= kMaximumNumberOfItemsToParse) {
        // Use didAbortParsing flag to distinguish between this real parser errors.
        didAbortParsing = YES;
        [parser abortParsing];
    }
    if ([elementName isEqualToString:kChannelElementName]) {
        NSMutableDictionary *channel = [[NSMutableDictionary alloc] init];
        self.currentFeedObject = channel;
        self.currentItemObject = channel;   // shortcut so parser can treat it the same
        [channel release];
    }
    if ([elementName isEqualToString:kItemElementName]) {
        if (self.currentFeedObject) {       // first item element, update the feed table
            [feedRecord setValue:trimString(flattenHTML([self.currentFeedObject objectForKey:kItemTitleKey])) forKey:kDBFeedTitleKey];
            [feedRecord setValue:trimString(flattenHTML([self.currentFeedObject objectForKey:kItemDescKey])) forKey:kDBFeedDescKey];
            [rssDB updateFeed:feedRecord forRowID:self.feedID];
            self.currentFeedObject = nil;
        }
        
        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
        [item setObject:self.feedID forKey:kItemFeedIDKey];
        self.currentItemObject = item;
        [item release];
    } else if ([containerElements containsObject:elementName]) {
        accumulatingParsedCharacterData = YES;
        // reset character accumulator
        [currentParsedCharacterData setString:@""];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {     
    // NSLog(@"%s (%@) data: %@", __FUNCTION__, elementName, currentParsedCharacterData);
    if ([elementName isEqualToString:kItemElementName]) {
        [currentParseBatch addObject:currentItemObject];
        parsedItemsCounter++;
        
        if (parsedItemsCounter % kSizeOfItemsBatch == 0) {
            // message(@"processing batch: %d", parsedItemsCounter);
            [self performSelectorOnMainThread:@selector(updateDBWithItems:) withObject:self.currentParseBatch waitUntilDone:NO];
            self.currentParseBatch = [NSMutableArray array];    // old array passed to updateDBWithItems
        }
    } else if ([elementName isEqualToString:kDescriptionElementName]) {
        NSString * currentString = [[[NSString alloc] initWithString: currentParsedCharacterData] autorelease];
        [self.currentItemObject setObject:currentString forKey:@"desc"];
    } else if ([elementName isEqualToString:kTitleElementName]) {
        NSString * currentString = [[[NSString alloc] initWithString: currentParsedCharacterData] autorelease];
        [self.currentItemObject setObject:currentString forKey:@"title"];
    } else if ([elementName isEqualToString:kLinkElementName]) {
        NSString * currentString = [[[NSString alloc] initWithString: currentParsedCharacterData] autorelease];
        [self.currentItemObject setObject:currentString forKey:@"url"];
    } else if ([elementName isEqualToString:kUpdatedElementName] || [elementName isEqualToString:kDCDateElementName]) {
        [self.currentItemObject setObject:[self dateStringToSQLDate:currentParsedCharacterData] forKey:@"pubdateSQLString"];
    }
    // Stop accumulating parsed character data. We won't start again until specific elements begin.
    accumulatingParsedCharacterData = NO;
}

// The parser delivers parsed character data (PCDATA) in chunks, not necessarily all at once. 
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    // NSLog(@"%s (%@)", __FUNCTION__, string);
    if (accumulatingParsedCharacterData) {
        [self.currentParsedCharacterData appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // We abort parsing if we get more than kMaximumNumberOfItemsToParse. 
    // We use the didAbortParsing flag to avoid treating this as an error. 
    if (didAbortParsing == NO) {
        // Pass the error to the main thread for handling.
        [self performSelectorOnMainThread:@selector(handleError:) withObject:parseError waitUntilDone:NO];
    }
}


#pragma mark -
#pragma mark Date parsing methods

-(NSString *) dateToLocalizedString:(NSDate *) date {
    // NSLog(@"%s %@", __FUNCTION__, date);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEEE, MMMM d, hh:mm a"];
    NSString *s = [dateFormatter stringFromDate:date];
    [dateFormatter release];
    return s;
}
-(NSDate *) SQLDateToDate:(NSString *) SQLDateString {
    // NSLog(@"%s %@", __FUNCTION__, SQLDateString);
    if ((id) SQLDateString == [NSNull null] || [SQLDateString length] == 0)
        return [NSDate date]; // current date/time
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];   // "SQL" format
    NSDate *date = [dateFormatter dateFromString:SQLDateString];
    [dateFormatter release];
    return date;
}

-(NSString *) dateStringToSQLDate:(NSString *) dateString {
    // NSLog(@"%s %@", __FUNCTION__, dateString);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLenient:NO];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];   // the formatter should live in UTC
    NSString *s = nil;
    
    NSArray *dateFormats = [NSArray arrayWithObjects:
                            @"EEE, dd MMM yyyy HHmmss zzz",  // no colons, see below
                            @"dd MMM yyyy HHmmss zzz",
                            @"yyyy-MM-dd'T'HHmmss'Z'",
                            @"yyyy-MM-dd'T'HHmmssZ",
                            @"EEE MMM dd HHmm zzz yyyy",
                            @"EEE MMM dd HHmmss zzz yyyy",
                            nil];
    
    // iOS's limited implementation of unicode date formating is missing support for colons in timezone offsets 
    // so we just take all the colons out of the string -- it's more flexible like this anyway
    dateString = [dateString stringByReplacingOccurrencesOfString:@":" withString:@""];
    NSDate * date = nil;
    for (NSString *format in dateFormats) {
        [dateFormatter setDateFormat:format];
        // store the NSDate object
        if((date = [dateFormatter dateFromString:dateString])) {
            // message(@"%@ (%@) -> %@", dateString, format, date);
            break;
        }
    }
    
    if (!date) date = [NSDate date];    // no date? use now.
    
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];   // SQL date format
    s = [dateFormatter stringFromDate:date];
    [dateFormatter release];
    return s;
}


#pragma mark -
#pragma mark Error handling

- (void)handleError:(NSError *)error {
    // NSLog(@"%s", __FUNCTION__);
    // NSLog(@"error is %@, %@", error, [error domain]);
    NSString *errorMessage = [error localizedDescription];
    
    // errors in NSXMLParserErrorDomain >= 10 are harmless parsing errors
    if ([error domain] == NSXMLParserErrorDomain && [error code] >= 10) {
        alertMessage(@"Cannot parse feed: %@", errorMessage);  // tell the user why parsing is stopped
    } else {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Error" message:errorMessage delegate:nil
                                  cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [alertView release];
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)errorAlert:(NSString *) message {
    // NSLog(@"%s", __FUNCTION__);
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"RSS Error" message:message delegate:nil
                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    [self dismissModalViewControllerAnimated:YES];
}

@end
