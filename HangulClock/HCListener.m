/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "HCListener.h"
#import "HCWebSocket.h"

@implementation HCListener {
    NSMutableDictionary* listeners;
}

- (id)init
{
    self = [super init];
    if (self) {
        listeners = [[NSMutableDictionary alloc] init];
        
        [[HCWebSocket sharedSocket] listen:^(id message) {
            [self handleMessage:message];
        }];
    }
    return self;
}

- (void)on:(NSString*)type do:(void (^)(id))callback
{
    if (!listeners[type]) {
        listeners[type] = [[NSMutableArray alloc] init];
    }
    
    [listeners[type] addObject:callback];
}

- (void)handleMessage:(id)message
{
    NSDictionary* parsedMessage = [NSJSONSerialization
        JSONObjectWithData: [message dataUsingEncoding:NSUTF8StringEncoding]
        options: 0
        error: nil
    ];
    
    NSString* type = parsedMessage[@"type"];
    if (!listeners[type]) {
        return;
    }
    
    for (void (^listener)(id) in listeners[type]) {
        listener(parsedMessage[@"payload"]);
    }
}

@end
