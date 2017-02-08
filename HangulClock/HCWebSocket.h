/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>
#import <SocketRocket/SRWebSocket.h>

@interface HCWebSocket : NSObject <SRWebSocketDelegate>

+ (id)sharedSocket;
- (void)open:(NSURL*)aUrl;
- (void)close;
- (void)send:(id)message;
- (void)listen:(void (^)(id))listener;

@end
