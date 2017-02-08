/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "HCDispatcher.h"
#import "HCWebSocket.h"

@implementation HCDispatcher


- (void)dispatch:(NSString*)type withPayload:(id)payload
{
    NSDictionary* message = @{ @"type": type, @"payload": payload };

    NSError* error;
    NSData* jsonData = [NSJSONSerialization
        dataWithJSONObject: message
        options: 0
        error: &error
    ];
    
    if (!jsonData) {
        NSLog(@"err: %@", error);
        return;
    }

    [[HCWebSocket sharedSocket]
        send: [[NSString alloc]
            initWithData:jsonData
            encoding:NSUTF8StringEncoding
        ]
    ];
}


@end
