/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>

@import WebKit;
@import CoreLocation;

@interface HCLocation : NSObject<CLLocationManagerDelegate, WKScriptMessageHandler>

//- (id) initWithContext:(JSContextRef)context;
//- (void)getCurrentPosition:(WebScriptObject *)callback;
@end
