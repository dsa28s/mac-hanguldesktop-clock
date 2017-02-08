/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>

@interface HCWidgetsStore : NSObject

- (void)onChange:(void (^)(NSDictionary*))aChangeHandler;
- (void)reset;
- (NSDictionary*)get:(NSString*)widgetId;
- (NSDictionary*)getSettings:(NSString*)widgetId;
- (NSArray*)sortedWidgets;

@end
