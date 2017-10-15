/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <AppKit/AppKit.h>
#import "AppDelegate.h"
#import "HCWidgetsController.h"
#import "HCWidgetsStore.h"
#import "HCScreensController.h"
#import "HCDispatcher.h"
#import "HCWidgetForScripting.h"

@interface TerminationListener: NSObject
{
    const char* executablePath;
    pid_t parentProcessId;
}

- (void) relaunch;
@end

@implementation TerminationListener
- (id) initWithExecutablePath:(const char *)execPath parentProcessId:(pid_t)ppid
{
    self = [super init];
    if (self != nil) {
        executablePath = execPath;
        parentProcessId = ppid;
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(applicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
        if (getppid() == 1) {
            [self relaunch];
        }
    }
    return self;
}

- (void) applicationDidTerminate:(NSNotification *)notification
{
    if (parentProcessId == [[[notification userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue]) {
        [self relaunch];
    }
}

- (void) relaunch
{
    [[NSWorkspace sharedWorkspace] launchApplication:[NSString stringWithUTF8String:executablePath]];
    exit(0);
}

@end

@implementation HCWidgetsController {
    HCWidgetsStore* widgets;
    HCScreensController* screensController;
    NSMenu* mainMenu;
    NSInteger currentIndex;
    NSImage* statusIconVisible;
    NSImage* statusIconHidden;
    HCDispatcher* dispatcher;
}

static NSInteger const WIDGET_MENU_ITEM_TAG = 42;

- (id)initWithMenu:(NSMenu*)menu
           widgets:(HCWidgetsStore*)theWidgets
           screens:(HCScreensController*)screens
{
    //self = [super init];
    
    
    if (self) {

        mainMenu = menu;
        widgets = theWidgets;
        screensController = screens;
        
        currentIndex = [self indexOfWidgetMenuItems:menu];
        [menu insertItem:[NSMenuItem separatorItem] atIndex:currentIndex];
        currentIndex++;
        NSMenuItem* header = [[NSMenuItem alloc] init];
        [header setTitle:@"시계 테마"];
        [header setState:0];
        [mainMenu insertItem:header atIndex:currentIndex];
        currentIndex++;
        [menu insertItem:[NSMenuItem separatorItem] atIndex:currentIndex];
        
        dispatcher = [[HCDispatcher alloc] init];
       
        statusIconVisible = [[NSBundle mainBundle]
            imageForResource:@"widget-status-visible"
        ];
        [statusIconVisible setTemplate:YES];
        
        statusIconHidden = [[NSBundle mainBundle]
            imageForResource:@"widget-status-hidden"
        ];
    }
    
    return self;
}


- (void)render
{
     for (NSMenuItem *item in [mainMenu itemArray]) {
        if (item.tag == WIDGET_MENU_ITEM_TAG) {
            [mainMenu removeItem: item];
        }
    }
    
    NSString* widgetId;
    NSString* error;
    for (NSInteger i = widgets.sortedWidgets.count - 1; i >= 0; i--) {
        widgetId = widgets.sortedWidgets[i];
        [self renderWidget:widgetId inMenu:mainMenu];
        
        error = [widgets get:widgetId][@"error"];
        if (error) {
            [self notifyUser:error withTitle:@"Error"];
        }
    }
}


- (void)renderWidget:(NSString*)widgetId inMenu:(NSMenu*)menu
{
    NSMenuItem* newItem = [[NSMenuItem alloc] init];
    
    NSString *blackString = @"블랙";
    NSString *whiteString = @"화이트";
    bool isFlag = false;
    
    //[newItem setTitle: widgetId];
    
    if ([widgetId containsString: blackString]) {
        [newItem setTitle:@"블랙 한글시계"];
        isFlag = true;
    } else if ([widgetId containsString: whiteString]) {
        [newItem setTitle:@"화이트 한글시계"];
        isFlag = true;
    }
    
    if(isFlag) {
        [newItem setRepresentedObject:widgetId];
        [newItem setTag:WIDGET_MENU_ITEM_TAG];
        
        [newItem
         setImage:[self isWidgetVisible:widgetId]
         ? statusIconVisible
         : statusIconHidden
         ];
        
        
        NSMenu* widgetMenu = [[NSMenu alloc] init];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
        [self addHideOptionToMenu:widgetMenu forWidget:widgetId];
        [self addMessageDisableOptionsToMenu:widgetMenu forWidget:widgetId];
        [self addCustomMessageDialogOptionsToMenu:widgetMenu forWidget:widgetId];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:2];
        [self addClockDirectionDetailOptionsToMenu:widgetMenu forWidget:widgetId];
        [self addClockDirectionOptionToMenu:widgetMenu forWidget:widgetId];
        [self addClockZoomDetailOptionsToMenu:widgetMenu forWidget:widgetId];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
        [self addClockZoomOptionMenu:widgetMenu forWidget:widgetId];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:5];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:11];
        
        [self
         addScreens: [screensController screens]
         toWidgetMenu: widgetMenu
         forWidget: widgetId
         ];
        
        [self addSelectedScreensOptionToMenu:widgetMenu forWidget:widgetId];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        [self addMainScreenOptionToMenu:widgetMenu forWidget:widgetId];
        [self addAllScreensOptionToMenu:widgetMenu forWidget:widgetId];
        
        
        //[self addEditMenuItemToMenu:widgetMenu forWidget:widgetId];
        [widgetMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
        
        
        [newItem setSubmenu:widgetMenu];
        [menu insertItem:newItem atIndex:currentIndex];
    } else {
        
    }
}

- (void)addEditMenuItemToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
        initWithTitle: @"Edit..."
        action: @selector(editWidget:)
        keyEquivalent: @""
    ];
    [item setRepresentedObject:widgetId];
    [item setTarget:self];
    [menu insertItem:item atIndex:0];

}

- (void)addMainScreenOptionToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
        initWithTitle: @"메인 디스플레이에서만 보이기"
        action: @selector(showOnMainScreen:)
        keyEquivalent: @""
    ];
    NSDictionary* settings = [widgets getSettings:widgetId];
    [item setTarget:self];
    [item setRepresentedObject:widgetId];
    [item setState:[settings[@"showOnMainScreen"] boolValue]];
    [menu insertItem:item atIndex:0];
}


- (void)addAllScreensOptionToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
        initWithTitle: @"모든 화면에서 보이기"
        action: @selector(showOnAllScreens:)
        keyEquivalent: @""
    ];
    NSDictionary* settings = [widgets getSettings:widgetId];
    [item setTarget:self];
    [item setRepresentedObject:widgetId];
    [item setState:[settings[@"showOnAllScreens"] boolValue]];
    [menu insertItem:item atIndex:0];
}

- (void)addHideOptionToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
        initWithTitle: @"시계 숨기기"
        action: @selector(toggleHidden:)
        keyEquivalent: @""
    ];
    
    NSDictionary* settings = [widgets getSettings:widgetId];
    [item setTarget:self];
    [item setRepresentedObject:widgetId];
    [item setState:[settings[@"hidden"] boolValue]];
    [menu insertItem:item atIndex:0];
}

- (void)addClockDirectionOptionToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc] init];
    NSDictionary* settings = [widgets getSettings:widgetId];
    
    [item setTitle:@"문구 방향"];
    [item setState:false];
    [item setEnabled:NO];
    [menu insertItem:item atIndex:0];
}

- (void)addClockZoomOptionMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc] init];
    NSDictionary* settings = [widgets getSettings:widgetId];
    
    [item setTitle:@"시계 크기"];
    [item setState:false];
    [item setEnabled:NO];
    [menu insertItem:item atIndex:0];
}

- (void)addClockZoomDetailOptionsToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSArray* directionStringArray = [NSArray arrayWithObjects:@"50%", @"75%", @"100%", nil];
    NSArray* directionPrefKeyArray = [NSArray arrayWithObjects:@"percent50", @"percent75", @"percent100", nil];
    SEL selectors[] = { @selector(toggleClockZoom_100:), @selector(toggleClockZoom_75:), @selector(toggleClockZoom_50_2:) };
    directionStringArray = [[directionStringArray reverseObjectEnumerator]allObjects];
    directionPrefKeyArray = [[directionPrefKeyArray reverseObjectEnumerator]allObjects];
    
    for(int i = 0; i < 3; i++) {
        NSMenuItem* item = [[NSMenuItem alloc]
                            initWithTitle: directionStringArray[i]
                            action: selectors[i]
                            keyEquivalent: @""
                            ];
        
        //NSDictionary* settings = [widgets getSettings:widgetId];
        [item setTarget:self];
        [item setRepresentedObject:widgetId];
        
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        
        [item setState:[[userDefaults objectForKey:@"clockZoom"]  isEqual: directionPrefKeyArray[i]]];
        [menu insertItem:item atIndex:0];
    }
}

- (void)addClockDirectionDetailOptionsToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSArray* directionStringArray = [NSArray arrayWithObjects:@"위", @"아래", @"왼쪽", @"오른쪽", nil];
    NSArray* directionPrefKeyArray = [NSArray arrayWithObjects:@"top", @"bottom", @"left", @"right", nil];
    SEL selectors[] = { @selector(toggleMessageDirection_Right:), @selector(toggleMessageDirection_Left:), @selector(toggleMessageDirection_Bottom:), @selector(toggleMessageDirection_Top:) };
    directionStringArray = [[directionStringArray reverseObjectEnumerator]allObjects];
    directionPrefKeyArray = [[directionPrefKeyArray reverseObjectEnumerator]allObjects];
    
    for(int i = 0; i < 4; i++) {
        NSMenuItem* item = [[NSMenuItem alloc]
                            initWithTitle: directionStringArray[i]
                            action: selectors[i]
                            keyEquivalent: @""
                            ];
        
        NSDictionary* settings = [widgets getSettings:widgetId];
        [item setTarget:self];
        [item setRepresentedObject:widgetId];
        
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        
        [item setState:[[userDefaults objectForKey:@"messageDirection"]  isEqual: directionPrefKeyArray[i]]];
        [menu insertItem:item atIndex:0];
    }
}

- (void)addMessageDisableOptionsToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
                        initWithTitle: @"문구 사용안함"
                        action: @selector(toggleDisableMessage:)
                        keyEquivalent: @""
                        ];
    
    NSDictionary* settings = [widgets getSettings:widgetId];
    [item setTarget:self];
    [item setRepresentedObject:widgetId];
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    [item setState:[[userDefaults objectForKey:@"messageDisabled"] isEqual: @"disabled"]];
    [menu insertItem:item atIndex:0];
}

- (void)addCustomMessageDialogOptionsToMenu:(NSMenu*)menu forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc]
                        initWithTitle: @"문구 사용자화"
                        action: @selector(toggleCustomMessage:)
                        keyEquivalent: @""
                        ];
    
    NSDictionary* settings = [widgets getSettings:widgetId];
    [item setTarget:self];
    [item setRepresentedObject:widgetId];
    
    [menu insertItem:item atIndex:0];
}

- (void)addSelectedScreensOptionToMenu:(NSMenu*)menu
                             forWidget:(NSString*)widgetId
{
    NSMenuItem* item = [[NSMenuItem alloc] init];
    NSDictionary* settings = [widgets getSettings:widgetId];
    
    [item  setTitle:@"선택된 디스플레이에서만 보이기:"];
    [item setState:[settings[@"showOnSelectedScreens"] boolValue]];
    [item setEnabled:NO];
    [menu insertItem:item atIndex:0];
}

- (void)removeWidget:(NSString*)widgetId FromMenu:(NSMenu*)menu
{
    [menu removeItem:[menu itemWithTitle:widgetId]];
}

- (void)addScreens:(NSDictionary*)screens
      toWidgetMenu:(NSMenu*)menu
      forWidget:(NSString*)widgetId
{
    NSString *title;
    NSMenuItem *newItem;
    NSString *name;
    NSArray* widgetScreens = [widgets getSettings:widgetId][@"screens"];
    
    newItem = [NSMenuItem separatorItem];
    [menu insertItem:newItem atIndex:0];
    
    int i = 0;
    for(NSNumber* screenId in screensController.sortedScreens) {
        name = screensController.screens[screenId];
        if(![name  isEqual: @"Built-in Display"]) {
            title = [NSString stringWithFormat:@"%@ 에서만 보이기", name];
            newItem = [[NSMenuItem alloc]
                       initWithTitle: title
                       action: @selector(toggleScreen:)
                       keyEquivalent: @""
                       ];
            
            [newItem setTarget:self];
            [newItem
             setRepresentedObject: @{
                                     @"screenId": screenId,
                                     @"widgetId": widgetId
                                     }
             ];
            
            if ([widgetScreens containsObject:screenId]) {
                [newItem setState:YES];
            }
            [menu insertItem:newItem atIndex:i];
            i++;
        }
    }
}

- (BOOL)isWidgetVisible:(NSString*)widgetId
{
    NSDictionary* settings = [widgets getSettings:widgetId];
    BOOL isVisible = NO;
    if ([settings[@"hidden"] boolValue]) {
        isVisible = NO;
    } else if ([settings[@"showOnAllScreens"] boolValue]) {
        isVisible = YES;
    } else if ([settings[@"showOnMainScreen"] boolValue]) {
        isVisible = YES;
    } else if ([settings[@"showOnSelectedScreens"] boolValue]) {
        NSMutableSet *intersection = [NSMutableSet
            setWithArray: settings[@"screens"]
        ];
        
        [intersection
            intersectSet:[NSSet setWithArray:[screensController sortedScreens]]
        ];
    
        isVisible = [intersection count] > 0;
     }
    
    return isVisible;
}


-(NSInteger)indexOfWidgetMenuItems:(NSMenu*)menu
{
    return [menu indexOfItem:[menu itemWithTitle:@"Check for Updates..."]] + 2;
}


- (void)showOnAllScreens:(id)sender
{
    NSString* widgetId = [(NSMenuItem*)sender representedObject];
    
    [dispatcher
        dispatch: @"WIDGET_SET_TO_ALL_SCREENS"
        withPayload: widgetId
    ];
}

- (void)showOnSelectedScreens:(id)sender
{
    NSString* widgetId = [(NSMenuItem*)sender representedObject];
    
    [dispatcher
        dispatch: @"WIDGET_SET_TO_SELECTED_SCREENS"
        withPayload: widgetId
    ];
}

- (void)showOnMainScreen:(id)sender
{
    NSString* widgetId = [(NSMenuItem*)sender representedObject];
    
    [dispatcher
        dispatch: @"WIDGET_SET_TO_MAIN_SCREEN"
        withPayload: widgetId
    ];
}

- (void)toggleHidden:(id)sender
{
    NSString* widgetId = [(NSMenuItem*)sender representedObject];
    NSDictionary* settings = [widgets getSettings:widgetId];
    BOOL isHidden = [settings[@"hidden"] boolValue];
    
    [dispatcher
        dispatch: isHidden ? @"WIDGET_SET_TO_SHOW" : @"WIDGET_SET_TO_HIDE"
        withPayload: widgetId
    ];
}

- (void)restartHangulClockDialog
{
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"한글시계 재시작";
    alert.informativeText = @"설정값을 반영하기 위해 한글시계가 재시작됩니다.";
    [alert addButtonWithTitle:@"확인"];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:@selector(someMethodDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)toggleMessageDirection_Top:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"top" forKey:@"messageDirection"];
    [userDefaults synchronize];

    [self restartHangulClockDialog];
}

- (void)toggleMessageDirection_Bottom:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"bottom" forKey:@"messageDirection"];
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleMessageDirection_Left:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"left" forKey:@"messageDirection"];
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleMessageDirection_Right:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"right" forKey:@"messageDirection"];
    [userDefaults synchronize];

    [self restartHangulClockDialog];
}

- (void)toggleClockZoom_50_2:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"percent50" forKey:@"clockZoom"];
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleClockZoom_75:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"percent75" forKey:@"clockZoom"];
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleClockZoom_100:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@"percent100" forKey:@"clockZoom"];
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleDisableMessage:(id)sender
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    if([[userDefaults objectForKey:@"messageDisabled"] isEqual:@"disabled"])
    {
        [userDefaults setObject:@"enabled" forKey:@"messageDisabled"];
    }
    else
    {
        [userDefaults setObject:@"disabled" forKey:@"messageDisabled"];
    }
    
    
    [userDefaults synchronize];
    
    [self restartHangulClockDialog];
}

- (void)toggleCustomMessage:(id)sender
{
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"문구 사용자화";
    alert.informativeText = @"문구를 입력해주세요. 다음줄로 개행할 경우 \\n를 입력합니다.\n(자동 문구를 사용할 경우 default 라고 입력해주세요)";
    [alert addButtonWithTitle:@"확인"];
    [alert addButtonWithTitle:@"취소"];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 400, 24)];
    [input setStringValue:@""];
    
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertFirstButtonReturn) {
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:[input stringValue] forKey:@"customMessage"];
        [userDefaults synchronize];
        
        [self restartHangulClockDialog];
    } else if (button == NSAlertSecondButtonReturn) {
        
    }
}

- (void) someMethodDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    /*NSArray *applications = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"me.sangs.hangul.coding.mac"];
    if (applications.count) {
        [(NSRunningApplication *)applications[0] terminate];
    }*/
    
    NSString* path = [[NSBundle mainBundle] resourcePath].stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSTask* task = [NSTask alloc];
    
    task.launchPath = @"/usr/bin/open";
    task.arguments = [NSArray arrayWithObjects:path, nil];
    [task launch];
    
    exit(0);
}

- (void)toggleScreen:(id)sender
{
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    NSDictionary* data = [menuItem representedObject];
    NSNumber* screenId = data[@"screenId"];
    NSDictionary* widgetSettings = [widgets getSettings:data[@"widgetId"]];
    NSString* message;
    
    if ([(NSArray*)widgetSettings[@"screens"] containsObject:screenId]) {
        message = @"SCREEN_DESELECTED_FOR_WIDGET";
    } else {
        message = @"SCREEN_SELECTED_FOR_WIDGET";
    }
    
    [dispatcher
        dispatch: @"WIDGET_SET_TO_SELECTED_SCREENS"
        withPayload: data[@"widgetId"]
    ];

    [dispatcher
        dispatch: message
        withPayload: @{
            @"id": data[@"widgetId"],
            @"screenId": screenId
        }
    ];
}

- (void)editWidget:(id)sender
{
    NSString* widgetId = [(NSMenuItem*)sender representedObject];
    NSString* filePath = [widgets get:widgetId][@"filePath"];
    
    if (![[NSWorkspace sharedWorkspace] openFile:filePath]) {
        NSString* message = @"Please configure an app to edit .%@ files";
        [self
            notifyUser: [NSString
                stringWithFormat: message, [filePath pathExtension]
            ]
            withTitle: @"No Editor Configured."
        ];
    }
}

- (void)notifyUser:(NSString*)message withTitle:(NSString*)title
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter]
        deliverNotification:notification
    ];
}

- (NSArray*)widgetsForScripting
{
    NSMutableArray* allWidgets = [NSMutableArray array];
    for ( NSString* widgetId in [widgets sortedWidgets]) {
        [allWidgets addObject: [[HCWidgetForScripting alloc]
                initWithId: widgetId
                andSettings: [widgets getSettings:widgetId]
            ]
        ];
    }
    return allWidgets;
}


@end
