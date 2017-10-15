/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "AppDelegate.h"
#import "HCWindow.h"
#import "HCPreferencesController.h"
#import "HCScreensController.h"
#import "HCKeyHandler.h"
#import "HCWidgetsController.h"
#import "HCWidgetsStore.h"
#import "HCWebSocket.h"
#import "WKInspector.h"
#import "WKView.h"
#import "WKPage.h"
#import "WKWebViewInternal.h"

#import <AppKit/AppKit.h>

@import WebKit;

int const PORT = 2320;

@implementation NSString (NSString_Extended)
- (NSString *)urlencode {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    int sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else if (thisChar == '\\' && source[i + 1] == 'n') {
            if(i + 1 < sourceLen) {
                [output appendString:@"%0A"];
            }
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    
    output = [output stringByReplacingOccurrencesOfString:@"%0An"
                                      withString:@"%0A"];
    return output;
}
@end

@implementation AppDelegate {
    NSStatusItem* statusBarItem;
    NSTask* widgetServer;
    HCPreferencesController* preferences;
    HCScreensController* screensController;
    BOOL keepServerAlive;
    int portOffset;
    HCKeyHandler* keyHandler;
    HCWidgetsStore* widgetsStore;
    HCWidgetsController* widgetsController;
    NSMutableDictionary* windows;
    BOOL needsRefresh;
}


@synthesize statusBarMenu;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    needsRefresh = YES;
    windows = [[NSMutableDictionary alloc] initWithCapacity:42];
    statusBarItem = [self addStatusItemToMenu: statusBarMenu];
    preferences = [[HCPreferencesController alloc]
        initWithWindowNibName:@"HCPreferencesController"
    ];

    // NSTask doesn't terminate when xcode stop is pressed. Other ways of
    // spawning the server, like system() or popen() have the same problem.
    // So, hit em with a hammer :(
    system("killall localnode");
    
    // start server and load webview
    portOffset = 0;
    keepServerAlive = YES;
    
    [self startServer: ^(NSString* output) {
        // note that these might be called several times
        if ([output rangeOfString:@"server started"].location != NSNotFound) {
            [widgetsStore reset];
            [[HCWebSocket sharedSocket] open:[self serverUrl:@"ws"]];
            // this will trigger a render
            [screensController syncScreens:self];

        } else if ([output rangeOfString:@"EADDRINUSE"].location != NSNotFound) {
            portOffset++;
            if (portOffset >= 20) {
                keepServerAlive = NO;
                NSLog(@"couldn't find an open port. Giving up...");
            }
        }
    }];
    
    // listen for keyboard events
    keyHandler = [[HCKeyHandler alloc]
        initWithPreferences: preferences
        listener: self
    ];
    
    widgetsStore = [[HCWidgetsStore alloc] init];

    screensController = [[HCScreensController alloc]
        initWithChangeListener:self
    ];
    
    widgetsController = [[HCWidgetsController alloc]
        initWithMenu: statusBarMenu
        widgets: widgetsStore
        screens: screensController
    ];
    [widgetsStore onChange: ^(NSDictionary* widgets) {
        [widgetsController render];
    }];
    
    // make sure notifcations always show
    NSUserNotificationCenter* unc = [NSUserNotificationCenter
        defaultUserNotificationCenter
    ];
    unc.delegate = self;
    

    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver: self
        selector: @selector(wakeFromSleep:)
        name: NSWorkspaceDidWakeNotification
        object: nil
    ];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver: self
        selector: @selector(workspaceChanged:)
        name: NSWorkspaceActiveSpaceDidChangeNotification
        object: nil
    ];
    
    [self listenToWallpaperChanges];
}

- (void)startServer:(void (^)(NSString*))callback
{
    NSLog(@"starting server task");

    void (^keepAlive)(NSTask*) = ^(NSTask* theTask) {
        if (keepServerAlive) {
            [self performSelector:@selector(startServer:) withObject:callback afterDelay:5.0];
        }
    };

    widgetServer = [self launchWidgetServer:[preferences.widgetDir path]
                                     onData:callback
                                     onExit:keepAlive];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    keepServerAlive = NO;
    [widgetServer terminate];
    [[NSStatusBar systemStatusBar] removeStatusItem:statusBarItem];
    
}

- (NSStatusItem*)addStatusItemToMenu:(NSMenu*)aMenu
{
    NSStatusBar*  bar = [NSStatusBar systemStatusBar];
    NSStatusItem* item;

    item = [bar statusItemWithLength: NSSquareStatusItemLength];
    
    NSImage *image = [[NSBundle mainBundle] imageForResource:@"status-icon"];
    [image setTemplate:YES];
    [item setImage: image];
    [item setHighlightMode:YES];
    [item setMenu:aMenu];
    [item setEnabled:YES];

    return item;
}

- (NSTask*)launchWidgetServer:(NSString*)widgetPath
                       onData:(void (^)(NSString*))dataHandler
                       onExit:(void (^)(NSTask*))exitHandler
{
    NSBundle* bundle     = [NSBundle mainBundle];
    NSString* nodePath   = [bundle pathForResource:@"localnode" ofType:nil];
    NSString* serverPath = [bundle pathForResource:@"server" ofType:@"js"];

    NSTask *task = [[NSTask alloc] init];

    [task setStandardOutput:[NSPipe pipe]];
    [task.standardOutput fileHandleForReading].readabilityHandler = ^(NSFileHandle *handle) {
        NSData *output = [handle availableData];
        NSString *outStr = [[NSString alloc]
            initWithData:output
            encoding:NSUTF8StringEncoding
        ];
        
        NSLog(@"%@", outStr);
        dispatch_async(dispatch_get_main_queue(), ^{
            dataHandler(outStr);
        });
    };
    
    task.terminationHandler = ^(NSTask *theTask) {
        [theTask.standardOutput fileHandleForReading].readabilityHandler = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            exitHandler(theTask);
        });
    };
    
    [task setLaunchPath:nodePath];
    [task setArguments:@[
        serverPath,
        @"-d", widgetPath,
        @"-p", [NSString stringWithFormat:@"%d", PORT + portOffset],
        @"-s", [[self getPreferencesDir] path]
        
    ]];
    
    [task launch];
    return task;
}


- (NSURL*)getPreferencesDir
{
    NSArray* urls = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask
    ];
    
    return [urls[0]
        URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]
                        isDirectory:YES
    ];
}

- (NSURL*)serverUrl:(NSString*)protocol
{
    int messageDirection = 0;
    int messageDisabled = 0;
    NSString *customMessage = @"";
    int zoom = 3;
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    if([[userDefaults objectForKey:@"messageDirection"] isEqual:@"top"])
    {
        messageDirection = 1;
    }
    else if([[userDefaults objectForKey:@"messageDirection"] isEqual:@"bottom"])
    {
        messageDirection = 2;
    }
    else if([[userDefaults objectForKey:@"messageDirection"] isEqual:@"left"])
    {
        messageDirection = 4;
    }
    else if([[userDefaults objectForKey:@"messageDirection"] isEqual:@"right"])
    {
        messageDirection = 3;
    }
    else
    {
        messageDirection = 1;
    }
    
    if([[userDefaults objectForKey:@"messageDisabled"] isEqual:@"disabled"])
    {
        messageDisabled = 1;
        messageDirection = 1;
    }
    else
    {
        messageDisabled = 0;
    }
    
    if([[userDefaults objectForKey:@"customMessage"] isEqual:@"default"] || [[userDefaults objectForKey:@"customMessage"] isEqual:@""] || [userDefaults objectForKey:@"customMessage"] == nil)
    {
        customMessage = @"default";
    }
    else
    {
        customMessage = [[userDefaults objectForKey:@"customMessage"] urlencode];
    }
    
    if([[userDefaults objectForKey:@"clockZoom"] isEqual:@"percent50"])
    {
        zoom = 1;
    }
    else if([[userDefaults objectForKey:@"clockZoom"] isEqual:@"percent75"])
    {
        zoom = 2;
    }
    else
    {
        zoom = 3;
    }
    
    // trailing slash required for load policy in HCWindow
    return [NSURL
        URLWithString:[NSString
            stringWithFormat:@"%@://127.0.0.1:%d/?messagePosition=%d&messageDisabled=%d&customMessage=%@&zoom=%d", protocol, PORT+portOffset, messageDirection, messageDisabled, customMessage, zoom
        ]
    ];
}

#
#pragma mark Screen Handling
#

- (void)screensChanged:(NSDictionary*)screens
{
    if (widgetsController) {
        [self renderOnScreens:screens];
    }
}

- (void)renderOnScreens:(NSDictionary*)screens
{
    NSMutableArray* obsoleteScreens = [[windows allKeys] mutableCopy];
    HCWindow* window;
    
    for(NSNumber* screenId in screens) {
        if (![windows objectForKey:screenId]) {
            window = [[HCWindow alloc] init];
            [windows setObject:window forKey:screenId];
            
            [window loadUrl:[
                [self serverUrl:@"http"]
                    URLByAppendingPathComponent:[NSString
                        stringWithFormat:@"%@",
                        screenId
                    ]
                ]
            ];
        } else {
            window = windows[screenId];
            if (needsRefresh) {
                [window reload];
            }
        }
        
        [window setFrame:[screensController screenRect:screenId] display:YES];
        [window makeKeyAndOrderFront:self];
        
        [obsoleteScreens removeObject:screenId];
    }
    
    for (NSNumber* screenId in obsoleteScreens) {
        [windows[screenId] close];
        [windows removeObjectForKey:screenId];
    }
    
    needsRefresh = NO;
    NSLog(@"using %lu screens", (unsigned long)[windows count]);
}

#
# pragma mark received actions
#

- (void)modifierKeyReleased
{
    for (NSNumber* screenId in windows) {
        [windows[screenId] sendToDesktop];
    }
}


- (void)modifierKeyPressed
{
   for (NSNumber* screenId in windows) {
        [windows[screenId] comeToFront];
    }
}

- (void)widgetDirDidChange
{
    for (NSNumber* screenId in screensController.screens) {
        [windows[screenId] close];
        [windows removeAllObjects];
    }
    
    [[HCWebSocket sharedSocket] close];
    
    if (widgetServer){
        // server will restart by itself
        [widgetServer terminate];
    }
}

- (void)compatibilityModeDidChange
{
    for (NSNumber* screenId in windows) {
        [windows[screenId] sendToDesktop];
    }
}

- (IBAction)showPreferences:(id)sender
{
    [preferences showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [preferences.window makeKeyAndOrderFront:self];
}

- (IBAction)refreshWidgets:(id)sender
{
    needsRefresh = YES;
    [screensController syncScreens:self];
}

- (void)detachInspector:(WKInspectorRef)inspector
{
     WKInspectorDetach(inspector);
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)wakeFromSleep:(NSNotification *)notification
{
     for (NSNumber* screenId in windows) {
        HCWindow* window = windows[screenId];
        [window reload];
    }
}

- (void)workspaceChanged:(NSNotification *)notification
{
    for (NSNumber* screenId in windows) {
        [windows[screenId] workspaceChanged];
    }
}

- (void)wallpaperChanged:(NSNotification *)notification
{
    for (NSNumber* screenId in windows) {
        [windows[screenId] wallpaperChanged];
    }
}

- (void)listenToWallpaperChanges
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSLibraryDirectory,
        NSUserDomainMask,
        YES
    );
    
    CFStringRef path = (__bridge CFStringRef)[paths[0]
        stringByAppendingPathComponent:@"/Application Support/Dock/"
    ];
    
    FSEventStreamContext context = {
        0,
        (__bridge void *)(self), NULL, NULL, NULL
    };
    FSEventStreamRef stream;
    
    stream = FSEventStreamCreate(
        NULL,
        &wallpaperSettingsChanged,
        &context,
        CFArrayCreate(NULL, (const void **)&path, 1, NULL),
        kFSEventStreamEventIdSinceNow,
        0,
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
    );
    
    FSEventStreamScheduleWithRunLoop(
        stream,
        CFRunLoopGetCurrent(),
        kCFRunLoopDefaultMode
    );
    FSEventStreamStart(stream);

}

void wallpaperSettingsChanged(
    ConstFSEventStreamRef streamRef,
    void *this,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]
)
{
    CFStringRef path;
    CFArrayRef  paths = eventPaths;

    for (int i=0; i < numEvents; i++) {
        path = CFArrayGetValueAtIndex(paths, i);
        if (CFStringFindWithOptions(path, CFSTR("desktoppicture.db"),
                                    CFRangeMake(0,CFStringGetLength(path)),
                                    kCFCompareCaseInsensitive,
                                    NULL) == true) {
            [(__bridge AppDelegate*)this
                performSelector:@selector(wallpaperChanged:)
                withObject:nil
                afterDelay:0.5
            ];
        }
    }
}

#
# pragma mark script support
#

- (NSArray*)getWidgets
{
   return [widgetsController widgetsForScripting];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    return [key isEqualToString:@"widgets"];
}

@end
