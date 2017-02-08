/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Foundation/Foundation.h>
@class HCWindow;
@class HCPreferencesController;


@interface HCKeyHandler : NSObject

- (id)initWithPreferences:(HCPreferencesController*)thePreferences
                 listener:(id)aListener;

@end
