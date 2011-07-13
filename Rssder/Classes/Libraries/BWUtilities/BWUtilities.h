//
//  BWUtilities.h
//  Rssder
//
//  Created by yangfei on 11-6-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

static NSString * const kBWUtilitiesVersion = @"1.0.5";
static NSString * const kAlertTitle = @"BW Sandbox";
static BOOL const kMessageActive = YES;

// populated from loadDidView
UITextView * messageTextView;

void message ( NSString *format, ... );
void alertMessage ( NSString *format, ... );
NSString * flattenHTML ( NSString * html );
NSString * trimString ( NSString * string );
