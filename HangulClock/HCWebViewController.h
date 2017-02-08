/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>
@import WebKit;

@interface HCWebViewController : NSObject<WKNavigationDelegate>

@property (strong, readonly) NSView* view;

- (id)initWithFrame:(NSRect)frame;
- (void)load:(NSURL*)url;
- (void)reload;
- (void)redraw;
- (void)destroy;

@end
