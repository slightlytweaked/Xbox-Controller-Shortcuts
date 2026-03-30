#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

static NSFileHandle *gLogFileHandle = nil;
static NSString *gLogFilePath = nil;

static void LogMessage(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    [gLogFileHandle seekToEndOfFile];
    [gLogFileHandle writeData:data];
    [gLogFileHandle synchronizeFile];
    fprintf(stderr, "%s", line.UTF8String);
}

static void SetupLogging(void) {
    NSString *executablePath = [[NSBundle mainBundle] executablePath] ?: NSProcessInfo.processInfo.arguments.firstObject;
    NSString *directory = [executablePath stringByDeletingLastPathComponent];
    gLogFilePath = [directory stringByAppendingPathComponent:@"xbox-controller-shortcuts.log"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:gLogFilePath]) {
        [[NSData data] writeToFile:gLogFilePath atomically:YES];
    }

    gLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:gLogFilePath];
}

@interface ShortcutEmitter : NSObject
- (BOOL)emitMapping:(NSDictionary *)mapping error:(NSError **)error;
@end

@interface ControllerBridge : NSObject
- (instancetype)initWithConfig:(NSDictionary *)config;
- (void)start;
@end

@implementation ShortcutEmitter

- (BOOL)emitMapping:(NSDictionary *)mapping error:(NSError **)error {
    NSArray *modifiers = mapping[@"modifiers"];
    NSString *key = mapping[@"key"];

    if (key == nil || key.length == 0) {
        LogMessage(@"Mapping is empty, skipping action");
        return YES;
    }

    if ([key isEqualToString:@"scroll_up"] || [key isEqualToString:@"scroll_down"]) {
        int32_t delta = [key isEqualToString:@"scroll_up"] ? 12 : -12;
        CGEventRef scroll = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1, delta);
        if (scroll == NULL) {
            return NO;
        }
        CGEventPost(kCGHIDEventTap, scroll);
        CFRelease(scroll);
        LogMessage(@"Posted scroll event key=%@ delta=%d", key, delta);
        return YES;
    }

    CGKeyCode keyCode = [self keyCodeForKey:key error:error];
    if (keyCode == UINT16_MAX) {
        return NO;
    }

    CGEventFlags flags = [self flagsForModifiers:modifiers error:error];
    if (flags == UINT64_MAX) {
        return NO;
    }

    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    if (keyDown == NULL || keyUp == NULL) {
        if (keyDown != NULL) CFRelease(keyDown);
        if (keyUp != NULL) CFRelease(keyUp);
        return NO;
    }

    CGEventSetFlags(keyDown, flags);
    CGEventSetFlags(keyUp, flags);
    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);
    LogMessage(@"Posted shortcut with modifiers=%@ key=%@", modifiers, key);
    CFRelease(keyDown);
    CFRelease(keyUp);
    return YES;
}

- (CGEventFlags)flagsForModifiers:(NSArray *)modifiers error:(NSError **)error {
    CGEventFlags flags = 0;

    for (id modifier in modifiers) {
        NSString *lower = [((NSString *)modifier) lowercaseString];
        if ([lower isEqualToString:@"command"] || [lower isEqualToString:@"cmd"]) {
            flags |= kCGEventFlagMaskCommand;
        } else if ([lower isEqualToString:@"shift"]) {
            flags |= kCGEventFlagMaskShift;
        } else if ([lower isEqualToString:@"option"] || [lower isEqualToString:@"alt"]) {
            flags |= kCGEventFlagMaskAlternate;
        } else if ([lower isEqualToString:@"control"] || [lower isEqualToString:@"ctrl"]) {
            flags |= kCGEventFlagMaskControl;
        } else {
            if (error != NULL) {
                *error = [NSError errorWithDomain:@"ShortcutEmitter"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Unsupported modifier: %@", modifier]}];
            }
            return UINT64_MAX;
        }
    }

    return flags;
}

- (CGKeyCode)keyCodeForKey:(NSString *)key error:(NSError **)error {
    static NSDictionary<NSString *, NSNumber *> *keyCodes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyCodes = @{
            @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"h": @4, @"g": @5, @"z": @6, @"x": @7, @"c": @8, @"v": @9,
            @"b": @11, @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"y": @16, @"t": @17, @"1": @18, @"2": @19,
            @"3": @20, @"4": @21, @"6": @22, @"5": @23, @"=": @24, @"9": @25, @"7": @26, @"-": @27, @"8": @28,
            @"0": @29, @"]": @30, @"o": @31, @"u": @32, @"[": @33, @"i": @34, @"p": @35, @"return": @36,
            @"enter": @36, @"l": @37, @"j": @38, @"'": @39, @"k": @40, @";": @41, @"\\": @42, @",": @43,
            @"/": @44, @"n": @45, @"m": @46, @".": @47, @"tab": @48, @"space": @49, @"`": @50, @"delete": @51,
            @"escape": @53, @"esc": @53, @"pageup": @116, @"pagedown": @121, @"left": @123, @"right": @124,
            @"down": @125, @"up": @126
        };
    });

    NSNumber *value = keyCodes[key.lowercaseString];
    if (value != nil) {
        return (CGKeyCode)value.unsignedShortValue;
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:@"ShortcutEmitter"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                [NSString stringWithFormat:@"Unsupported key: %@", key]}];
    }
    return UINT16_MAX;
}

@end

@interface ControllerBridge ()
@property (nonatomic, strong) NSDictionary *config;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *mappings;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *lastFireTimes;
@property (nonatomic, strong) ShortcutEmitter *emitter;
@property (nonatomic, assign) NSTimeInterval repeatDelay;
@property (nonatomic, strong) NSMutableArray<GCControllerButtonInput *> *retainedButtons;
@property (nonatomic, strong) NSMutableArray<GCExtendedGamepad *> *retainedProfiles;
@end

@implementation ControllerBridge

- (instancetype)initWithConfig:(NSDictionary *)config {
    self = [super init];
    if (self) {
        _config = config;
        _mappings = config[@"mappings"] ?: @{};
        _lastFireTimes = [NSMutableDictionary dictionary];
        _emitter = [[ShortcutEmitter alloc] init];
        _retainedButtons = [NSMutableArray array];
        _retainedProfiles = [NSMutableArray array];

        NSNumber *delayMs = config[@"repeatDelayMilliseconds"];
        _repeatDelay = delayMs != nil ? delayMs.doubleValue / 1000.0 : 0.25;
    }
    return self;
}

- (void)start {
    [self logAccessibilityStatus];
    if (@available(macOS 11.3, *)) {
        GCController.shouldMonitorBackgroundEvents = YES;
        LogMessage(@"Background controller events: enabled");
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDidConnect:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil];

    for (GCController *controller in GCController.controllers) {
        [self registerController:controller];
    }

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
    if (GCController.controllers.count == 0) {
        LogMessage(@"Waiting for controller connection...");
    }
}

- (void)controllerDidConnect:(NSNotification *)notification {
    GCController *controller = notification.object;
    if (controller != nil) {
        [self registerController:controller];
    }
}

- (void)registerController:(GCController *)controller {
    LogMessage(@"Connected controller: %@", controller.vendorName ?: @"Unknown");

    GCExtendedGamepad *extended = controller.extendedGamepad;
    if (extended == nil) {
        LogMessage(@"Controller does not expose an extended gamepad profile.");
        return;
    }

    [self.retainedButtons removeAllObjects];
    [self.retainedProfiles removeAllObjects];
    [self.retainedProfiles addObject:extended];

    __weak typeof(self) weakSelf = self;
    extended.valueChangedHandler = ^(GCExtendedGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
        LogMessage(@"Profile value changed: %@", element.localizedName ?: NSStringFromClass(element.class));
        [weakSelf handleElementChange:element onGamepad:gamepad];
    };

    [self bindButtonNamed:@"lb" input:extended.leftShoulder];
    [self bindButtonNamed:@"rb" input:extended.rightShoulder];
    [self bindButtonNamed:@"lt" input:extended.leftTrigger];
    [self bindButtonNamed:@"rt" input:extended.rightTrigger];
    [self bindButtonNamed:@"a" input:extended.buttonA];
    [self bindButtonNamed:@"b" input:extended.buttonB];
    [self bindButtonNamed:@"x" input:extended.buttonX];
    [self bindButtonNamed:@"y" input:extended.buttonY];
    [self bindButtonNamed:@"l3" input:extended.leftThumbstickButton];
    [self bindButtonNamed:@"r3" input:extended.rightThumbstickButton];
    [self bindButtonNamed:@"dpad_up" input:extended.dpad.up];
    [self bindButtonNamed:@"dpad_down" input:extended.dpad.down];
    [self bindButtonNamed:@"dpad_left" input:extended.dpad.left];
    [self bindButtonNamed:@"dpad_right" input:extended.dpad.right];
    [self bindButtonNamed:@"view" input:(extended.buttonOptions ?: extended.buttonHome)];
    [self bindButtonNamed:@"menu" input:extended.buttonMenu];
}

- (void)bindButtonNamed:(NSString *)name input:(GCControllerButtonInput *)button {
    if (button == nil) {
        return;
    }

    NSDictionary *mapping = self.mappings[name.lowercaseString];
    if (mapping == nil) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    button.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull buttonInput, float value, BOOL pressed) {
        LogMessage(@"Button changed: %@ value=%.3f pressed=%@", name, value, pressed ? @"YES" : @"NO");
        if (!pressed) {
            return;
        }
        LogMessage(@"Button pressed: %@", name);
        [weakSelf fireButton:name mapping:mapping];
    };
    [self.retainedButtons addObject:button];
}

- (void)fireButton:(NSString *)name mapping:(NSDictionary *)mapping {
    NSDate *now = [NSDate date];
    NSDate *lastDate = self.lastFireTimes[name];
    if (lastDate != nil && [now timeIntervalSinceDate:lastDate] < self.repeatDelay) {
        return;
    }

    self.lastFireTimes[name] = now;

    NSError *error = nil;
    if ([self.emitter emitMapping:mapping error:&error]) {
        NSArray *modifiers = mapping[@"modifiers"] ?: @[];
        NSString *joined = [modifiers componentsJoinedByString:@"+"];
        NSString *key = mapping[@"key"] ?: @"";
        if (joined.length > 0) {
            LogMessage(@"Triggered %@ -> %@+%@", name, joined, key);
        } else {
            LogMessage(@"Triggered %@ -> %@", name, key);
        }
    } else {
        LogMessage(@"Error triggering %@: %@", name, error.localizedDescription);
    }
}

- (void)handleElementChange:(GCControllerElement *)element onGamepad:(GCExtendedGamepad *)gamepad {
    NSDictionary<NSString *, GCControllerButtonInput *> *buttonMap = @{
        @"lb": gamepad.leftShoulder,
        @"rb": gamepad.rightShoulder,
        @"lt": gamepad.leftTrigger,
        @"rt": gamepad.rightTrigger,
        @"a": gamepad.buttonA,
        @"b": gamepad.buttonB,
        @"x": gamepad.buttonX,
        @"y": gamepad.buttonY,
        @"l3": gamepad.leftThumbstickButton ?: (GCControllerButtonInput *)NSNull.null,
        @"r3": gamepad.rightThumbstickButton ?: (GCControllerButtonInput *)NSNull.null,
        @"dpad_up": gamepad.dpad.up,
        @"dpad_down": gamepad.dpad.down,
        @"dpad_left": gamepad.dpad.left,
        @"dpad_right": gamepad.dpad.right,
        @"view": (gamepad.buttonOptions ?: gamepad.buttonHome) ?: (GCControllerButtonInput *)NSNull.null,
        @"menu": gamepad.buttonMenu
    };

    for (NSString *name in buttonMap) {
        id candidate = buttonMap[name];
        if (candidate == (id)NSNull.null) {
            continue;
        }

        GCControllerButtonInput *button = (GCControllerButtonInput *)candidate;
        if (element == button) {
            LogMessage(@"Matched profile element to mapping: %@", name);
            if (button.isPressed) {
                NSDictionary *mapping = self.mappings[name];
                if (mapping != nil) {
                    [self fireButton:name mapping:mapping];
                }
            }
            break;
        }
    }
}

- (void)logAccessibilityStatus {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    BOOL trusted = AXIsProcessTrusted();
    if (trusted) {
        LogMessage(@"Accessibility permission: granted");
    } else {
        LogMessage(@"Accessibility permission: not granted");
        LogMessage(@"Enable access for the app launching this tool in System Settings > Privacy & Security > Accessibility");
        LogMessage(@"If you launched with start.command, allow Terminal.app");
    }
}

@end

static NSDictionary *LoadConfig(NSString *path, NSError **error) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (data == nil) {
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"Config"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Config root must be a JSON object."}];
        }
        return nil;
    }

    return (NSDictionary *)object;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SetupLogging();
        LogMessage(@"Log file: %@", gLogFilePath);

        if (argc < 2) {
            fprintf(stderr, "Usage: xbox-controller-shortcuts /absolute/path/to/config.json\n");
            return 1;
        }

        NSString *configPath = [NSString stringWithUTF8String:argv[1]];
        NSError *error = nil;
        NSDictionary *config = LoadConfig(configPath, &error);
        if (config == nil) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        ControllerBridge *bridge = [[ControllerBridge alloc] initWithConfig:config];
        [bridge start];
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
