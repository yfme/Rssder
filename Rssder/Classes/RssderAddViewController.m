//
//  RssderAddViewController.m
//  Rssder
//
//  Created by yangfei on 11-7-1.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "RssderAddViewController.h"


@implementation RssderAddViewController

@synthesize urlField, labelStatus;
@synthesize delegate, rssDB, rssTableView;
@synthesize feedConnection, xmlData, feedRecord, feedURL, feedHost;

#pragma mark Constants
// RSS MIME-type suffix
static NSString * const kRSSMIMESuffix = @"xml";

// rssRecord keys
static NSString * const kTitleKey = @"title";
static NSString * const kDescriptionKey = @"desc";
static NSString * const kUrlKey = @"url";

// RSS element names
static NSString * const kTitleElementName = @"title";
static NSString * const kDescriptionElementName = @"description";
static NSString * const kItemElementName = @"item";

// status line background flag
static BOOL haveBGColor;

#pragma mark -
#pragma mark UIViewController delegate methods

- (void) dealloc {
    // NSLog(@"%s", __FUNCTION__);
    delegate = nil;
    if (feedURL) [feedURL release];
    if (feedHost) [feedHost release];
    if (feedRecord) [feedRecord release];
    if (xmlData) [xmlData release];
    [super dealloc];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    haveBGColor = NO;
    [urlField becomeFirstResponder];    // give focus to urlField
}

- (BOOL) textFieldShouldReturn: (UITextField *) textField {
    [self addFeedButtonPressed:self];
    return YES;
}

- (IBAction)addFeedButtonPressed:(id)sender {
    if (feedConnection) {
        [self.feedConnection cancel];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;   
    }
    
    // disable the text field and gray it out (to make it look disabled)
    self.urlField.enabled = NO;
    self.urlField.textColor = [UIColor grayColor];
    
    // get the feed
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self getRSSFeed:trimString(self.urlField.text)];
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark RSS Feed Management

- (void) getRSSFeed:(NSString *) url {
    // NSLog(@"%s", __FUNCTION__);
    
    if ([url length] < 1) return;  // don't bother with empty string
    if (!([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])) {
        url = [@"http://" stringByAppendingString:url];
    }
    
    [self fetchURL:url withState:BWRSS_STATE_DISCOVERY];
}

- (void) fetchURL:(NSString *) url withState:(BOOL) urlState {
    // NSLog(@"%s %@ %d", __FUNCTION__, url, urlState);
    bwrssState = urlState;
    // self.xmlData = [NSMutableData dataWithCapacity:0];
    self.xmlData = [[[NSMutableData alloc] init] autorelease];
    [self statusMessage:@"Requesting %@", url];
    NSURLRequest *rssURLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    self.feedConnection = [[[NSURLConnection alloc] initWithRequest:rssURLRequest delegate:self] autorelease];
    NSAssert(self.feedConnection != nil, @"Could not create xmlConnection");
}

// findFeedURL
// callback from connectionDidFinishLoading
// find a feed URL in an HTML page
- (void) findFeedURL {
    // NSLog(@"%s, data length: %d", __FUNCTION__, [xmlData length]);
    if ([xmlData length] < minPageSize) {
        [self errorAlert:@"Page is empty."];
        return;
    }
    
    // web pages can be huge. we havd no use for more than maxPageSize bytes
    NSUInteger len = [xmlData length];
    if (len > maxPageSize) len = maxPageSize;
    
    NSString * pageString = [[NSString alloc]
                             initWithBytesNoCopy: (void *)[xmlData bytes]
                             length:len
                             encoding:NSUTF8StringEncoding
                             freeWhenDone:NO];
    NSDictionary * rssLink = [self rssLinkFromHTML:pageString];
    
    [pageString release];
    [xmlData setLength:0];
    
    if (rssLink) {
        [self fetchURL:[rssLink objectForKey:@"href"] withState:BWRSS_STATE_PARSE_HEADER];
    } else {
        [self errorAlert:@"Did not find a feed."];
    }
}

- (void) haveFeed {
    // NSLog(@"%s, %@", __FUNCTION__, feedRecord);
    // default values
    if (![feedRecord objectForKey:kTitleElementName])
        [feedRecord setValue:self.feedHost forKey:kTitleElementName];
    if (![feedRecord objectForKey:kDescriptionElementName])
        [feedRecord setValue:@"" forKey:kDescriptionElementName];
    
    [feedRecord setValue:trimString(flattenHTML([self.feedRecord valueForKey:kTitleElementName])) forKey:kTitleKey];
    [feedRecord setValue:trimString(flattenHTML([self.feedRecord valueForKey:kDescriptionElementName])) forKey:kDescriptionKey];
    [feedRecord removeObjectForKey:kDescriptionElementName];    // not a database column
    
    [delegate haveAddViewRecord:feedRecord];
    [self dismissModalViewControllerAnimated:YES];
}

- (void)parseRSSHeader {
    // NSLog(@"%s", __FUNCTION__);
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
    [parser setDelegate:self];
    [parser parse];
    [parser release];
}

#pragma mark -
#pragma mark RSS discovery methods

- (NSDictionary *) rssLinkFromHTML:(NSString *) htmlString {
    // NSLog(@"%s: htmlString %d bytes", __FUNCTION__, [htmlString length]);
    NSDictionary * rssLink = nil;
    
    // set up the string scanner
    NSScanner * pageScanner = [NSScanner scannerWithString:htmlString];
    [pageScanner setCaseSensitive:NO];
    [pageScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    while ([pageScanner scanUpToString:@"<link " intoString:nil]) {
        NSString * linkString = nil;
        if ([pageScanner scanUpToString:@">" intoString:&linkString]) {
            rssLink = [self getAttributes:linkString];
            NSString * attRel = [rssLink valueForKey:@"rel"];
            NSString * attType = [rssLink valueForKey:@"type"];
            if (attRel && attType &&
                [attRel caseInsensitiveCompare:@"alternate"] == NSOrderedSame &&
                ( [attType caseInsensitiveCompare:@"application/rss+xml"] == NSOrderedSame ||
                 [attType caseInsensitiveCompare:@"application/atom+xml"] == NSOrderedSame ) ) {
                    break;
                } else {
                    rssLink = nil;
                }
            
        }
    }
    if (rssLink && ![rssLink valueForKey:@"href"]) rssLink = nil;
    return rssLink;
}

// (NSDictionary *) getAttributes:(NSString *) htmlTag
// pass in a tag like "<tag foo="bar" baz="boz"> ... 
// (ending ">" or "/>" optional, for convenience)
// and get back a dictionary with attributes as keys
- (NSDictionary *) getAttributes:(NSString *) htmlTag {
    // NSLog(@"%s: %@", __FUNCTION__, htmlTag);
    NSMutableDictionary * attribs = [NSMutableDictionary dictionaryWithCapacity:2];
    NSString * attributeString = nil;
    NSString * valueString = nil;
    
    NSScanner * linkScanner = [NSScanner scannerWithString:htmlTag];
    [linkScanner setCaseSensitive:NO];
    [linkScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [linkScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:nil];
    
    while([linkScanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&attributeString]) {
        if([linkScanner scanString:@"=\"" intoString:nil] && [linkScanner scanUpToString:@"\"" intoString:&valueString]) {
            [attribs setObject:valueString forKey:attributeString];
        }
        [linkScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:nil];
    }
    
    return attribs;
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // NSLog(@"%s %@", __FUNCTION__, [response MIMEType]);
    [self statusMessage:@"Connected to %@", [response URL]];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    // test the MIME type to see if it's a web page or an RSS feed
    if (bwrssState == BWRSS_STATE_DISCOVERY && [[response MIMEType] hasSuffix:kRSSMIMESuffix]) {
        bwrssState = BWRSS_STATE_PARSE_HEADER;
    }
    
    if (bwrssState == BWRSS_STATE_PARSE_HEADER) {
        self.feedURL = [[response URL] absoluteString];
        self.feedHost = [[response URL] host];
    }
    
    // reset the data object
    if ([xmlData length]) [xmlData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // NSLog(@"%s (length: %d)", __FUNCTION__, [data length]);
    if ( (bwrssState == BWRSS_STATE_DISCOVERY) && ([xmlData length] > maxPageSize) ) {
        [connection cancel];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;   
        [self findFeedURL];
    } else {
        [xmlData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // NSLog(@"%s", __FUNCTION__);
    self.feedConnection = nil;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    switch (bwrssState) {
        case BWRSS_STATE_DISCOVERY:
            [self findFeedURL];
            break;
        case BWRSS_STATE_PARSE_HEADER:
            NSLog(@"have RSS feed header (%d bytes)",[xmlData length]);
            // [self parseRSSHeader];
            break;
        default:
            NSAssert(0, @"invalid bwrssState");
            break;
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // NSLog(@"%s", __FUNCTION__);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if ([error code] == kCFURLErrorNotConnectedToInternet) {
        // if we can identify the error, we can present a more precise message to the user.
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(
                                                                                      @"No Connection Error",
                                                                                      @"Not connected to the Internet.") forKey:NSLocalizedDescriptionKey];
        NSError *noConnectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:userInfo];
        [self handleURLError:noConnectionError];
    } else {
        // otherwise handle the error generically
        [self handleURLError:error];
    }
    self.feedConnection = nil;
}

#pragma mark -
#pragma mark Utilities

- (void) statusMessage:(NSString *) format, ... {
    va_list args;
    va_start(args, format);
    
    NSString *outstr = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if (!haveBGColor) {
        labelStatus.backgroundColor = [UIColor lightTextColor];
        labelStatus.backgroundColor = [labelStatus.backgroundColor colorWithAlphaComponent:.25];
        haveBGColor = YES;
    }
    
    labelStatus.text = outstr;
    [outstr release];
}

- (void) clearStatusMessage {
    haveBGColor = NO;
    labelStatus.backgroundColor = [UIColor clearColor];
    labelStatus.text = @"";
}

#pragma mark -
#pragma mark Error handling

- (void)handleURLError:(NSError *)error {
    // NSLog(@"%s", __FUNCTION__);
    [delegate haveAddViewURLError:error];
    [self dismissModalViewControllerAnimated:YES];
}

- (void)errorAlert:(NSString *) message {
    // NSLog(@"%s", __FUNCTION__);
    [delegate haveAddViewRSSError:message];
    [self dismissModalViewControllerAnimated:YES];
}

@end
