//
//  RssderWebViewController.m
//  Rssder
//
//  Created by yangfei on 11-7-13.
//  Copyright 2011年 appxyz.com. All rights reserved.
//

#import "RssderWebViewController.h"


@implementation RssderWebViewController

@synthesize myWebView, urlString, feedItem, backButton, forwardButton;

static NSString * const kDBItemUrlKey = @"url";

- (void)viewDidLoad {
    // NSLog(@"%s feedItem: %@", __FUNCTION__, feedItem);
    [super viewDidLoad];
    self.title = [feedItem valueForKey:@"title"];
    self.myWebView.scalesPageToFit = YES;
    self.myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    [myWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[feedItem valueForKey:kDBItemUrlKey]]]];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    // release and set to nil
    self.myWebView = nil;   // property doesn't use alloc/init
}

- (void)dealloc {
    [super dealloc];
    myWebView.delegate = nil;
}

#pragma mark -
#pragma mark UIViewController delegate methods

- (void)viewWillAppear:(BOOL)animated {
    self.myWebView.delegate = self; // setup the delegate as the web view is shown
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.myWebView stopLoading];   // in case the web view is still loading its content
    self.myWebView.delegate = nil;  // disconnect the delegate as the webview is hidden
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO; // turn off the twirly
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // we support rotation in this view controller
    return YES;
}

- (IBAction) launchSafari:(id)sender {
    // NSLog(@"%s", __FUNCTION__);
    // to load original page in Safari
    // [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[feedItem valueForKey:kDBItemUrlKey]]];
    
    // to load current page in Safari
    [[UIApplication sharedApplication] openURL:[[myWebView request] URL]];
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
    // NSLog(@"%s", __FUNCTION__);
    // starting the load, show the activity indicator (twirly) in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    backButton.enabled = [webView canGoBack];
    forwardButton.enabled = [webView canGoForward];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // NSLog(@"%s %@", __FUNCTION__, [[[webView request] URL] absoluteString]);
    // finished loading, hide the activity indicator in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // load error, hide the activity indicator in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // report the error inside the webview
    // NSLog(@"webView didFailLoadWithError: %@, %d", [webView.request URL], [error code]);
    if (error.code != -999) {
        NSString* errorString =
        [NSString stringWithFormat:
         @"<html><style>\n"
         @"body {background-color: #ccc; margin-top: 50px;}\n"
         @".e1 { font-family: verdana, sans-serif; color:#f66; font-size: 32px; font-weight:bold; text-align: center; }\n"
         @".e2 { font-family: verdana; color:#066; font-size: 32px; font-weight:bold; text-align: center; }\n"
         @".u1 { font-family: monospace; color:#000; font-size: 24px; text-align: center; }\n"
         @"</style>\n"
         @"<p class='e1'>Error fetching web page:</p>\n"
         @"<p class='u1'>%@</p>\n"
         @"<p class='e2'>%@</p>\n"
         @"</html>",
         [[[webView request] URL] absoluteString],
         error.localizedDescription];
        [self.myWebView loadHTMLString:errorString baseURL:nil];
    }
}

@end
