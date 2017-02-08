/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>


@interface HCDispatcher : NSObject

- (void)dispatch:(NSString*)type withPayload:(id)payload;

@end
