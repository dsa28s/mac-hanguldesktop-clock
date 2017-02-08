/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "HCKeyHandler.h"
#import "HCWindow.h"
#import "HCPreferencesController.h"

@implementation HCKeyHandler {
    HCPreferencesController* preferences;
    id listener;
}

- (id)initWithPreferences:(HCPreferencesController*)thePreferences
                 listener:(id)aListener
{
    self = [super init];
    
    if (self) {
        preferences = thePreferences;
        listener = aListener;
        
        // listen to keyboard events
        CFMachPortRef eventTap = CGEventTapCreate(
            kCGHIDEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            CGEventMaskBit(kCGEventFlagsChanged),
            &onModifierKeyChange,
            (__bridge void *)(self)
        );
        CFRunLoopSourceRef runLoopSourceRef = CFMachPortCreateRunLoopSource(
            NULL,
            eventTap,
            0
        );
        CFRelease(eventTap);
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            runLoopSourceRef,
            kCFRunLoopDefaultMode
        );
        CFRelease(runLoopSourceRef);
    }
    
    return self;
}

- (HCPreferencesController*)preferences
{
    return preferences;
}

- (void)modifierKeyReleased
{
    [listener modifierKeyReleased];
}


- (void)modifierKeyPressed
{
    [listener modifierKeyPressed];
}

CGEventRef onModifierKeyChange(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* self)
{
    
    HCKeyHandler* this = (__bridge HCKeyHandler*)self;
    if((CGEventGetFlags(event) & [this.preferences interactionShortcut]) == 0) {
        [this modifierKeyReleased];
    } else {
        [this modifierKeyPressed];
    }

    return event;
}


@end
