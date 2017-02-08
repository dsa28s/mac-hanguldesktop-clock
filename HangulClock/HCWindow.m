/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "HCWindow.h"
#import "HCWebViewController.h"

@implementation HCWindow {
    HCWebViewController* webViewController;
}

- (id)init
{

    self = [super
        initWithContentRect: NSMakeRect(0, 0, 0, 0)
        styleMask: NSBorderlessWindowMask
        backing: NSBackingStoreBuffered
        defer: NO
    ];
    
    if (self) {
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self sendToDesktop];
        [self setCollectionBehavior:(
            NSWindowCollectionBehaviorTransient |
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorIgnoresCycle
        )];

        [self setRestorable:NO];
        [self disableSnapshotRestoration];
        [self setDisplaysWhenScreenProfileChanges:YES];
        [self setReleasedWhenClosed:NO];
        
        webViewController = [[HCWebViewController alloc]
            initWithFrame: [self frame]
        ];
        [self setContentView:webViewController.view];
    }

    return self;
}



- (void)loadUrl:(NSURL*)url
{
    [webViewController load:url];
}

- (void)reload
{
    [webViewController reload];
}


- (void)close
{
    [webViewController destroy];
    [super close];
}



#
#pragma mark signals/events
#

- (void)workspaceChanged
{
    [webViewController
        performSelector: @selector(redraw)
        withObject: nil
        afterDelay: 0.016
    ];
    [webViewController
        performSelector: @selector(redraw)
        withObject: nil
        afterDelay: 0.032
    ];
}

- (void)wallpaperChanged
{
    [webViewController redraw];
}

#
#pragma mark window control
#


- (void)sendToDesktop
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults valueForKey:@"compatibilityMode"] boolValue]) {
        [self setLevel:kCGDesktopWindowLevel - 1];
    } else {
        [self setLevel:kCGDesktopWindowLevel];
    }
}

- (void)comeToFront
{
    if (self.isInFront) return;

    [self setLevel:kCGNormalWindowLevel-1];
    [NSApp activateIgnoringOtherApps:NO];
    [self makeKeyAndOrderFront:self];
}

- (BOOL)isInFront
{
    return self.level == kCGNormalWindowLevel-1;
}


#
#pragma mark flags
#

- (BOOL)canBecomeKeyWindow { return [self isInFront]; }
- (BOOL)canBecomeMainWindow { return [self isInFront]; }
- (BOOL)acceptsFirstResponder { return [self isInFront]; }
- (BOOL)acceptsMouseMovedEvents { return [self isInFront]; }

@end
