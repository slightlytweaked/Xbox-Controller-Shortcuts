#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

static NSString * const XCAppName = @"Xbox Controller Shortcuts";
static NSString * const XCBundleIdentifier = @"com.marc.xbox-controller-shortcuts";

static NSString *XCLogPath(void) {
    NSString *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [appSupport stringByAppendingPathComponent:XCAppName];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"app.log"];
}

static void XCLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *logPath = XCLogPath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        [data writeToFile:logPath atomically:YES];
    } else {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    }
    fprintf(stderr, "%s", line.UTF8String);
}

static NSArray<NSString *> *XCButtonOrder(void) {
    return @[@"dpad_up", @"dpad_down", @"dpad_left", @"dpad_right",
             @"lb", @"lt", @"rb", @"rt",
             @"a", @"b", @"x", @"y",
             @"view", @"menu", @"home",
             @"l3", @"r3"];
}

static NSString *XCButtonDisplayName(NSString *buttonName) {
    static NSDictionary<NSString *, NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{
            @"dpad_up": @"D-pad Up",
            @"dpad_down": @"D-pad Down",
            @"dpad_left": @"D-pad Left",
            @"dpad_right": @"D-pad Right",
            @"lb": @"LB",
            @"lt": @"LT",
            @"rb": @"RB",
            @"rt": @"RT",
            @"a": @"A",
            @"b": @"B",
            @"x": @"X",
            @"y": @"Y",
            @"view": @"View",
            @"menu": @"Menu",
            @"home": @"Home",
            @"l3": @"L3",
            @"r3": @"R3",
        };
    });
    return names[buttonName] ?: buttonName.uppercaseString;
}

static NSSet<NSString *> *XCSupportedNamedKeys(void) {
    static NSSet<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[@"return", @"enter", @"tab", @"space", @"delete", @"escape", @"esc",
                                     @"pageup", @"pagedown", @"left", @"right", @"up", @"down",
                                     @"scroll_up", @"scroll_down"]];
    });
    return keys;
}

static NSString *XCNormalizeKeyString(NSString *raw) {
    if (![raw isKindOfClass:[NSString class]]) {
        return @"";
    }

    NSString *trimmed = [[raw lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }

    static NSDictionary<NSString *, NSString *> *hangulToQwerty;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hangulToQwerty = @{
            @"ㅂ": @"q", @"ㅈ": @"w", @"ㄷ": @"e", @"ㄱ": @"r", @"ㅅ": @"t",
            @"ㅛ": @"y", @"ㅕ": @"u", @"ㅑ": @"i", @"ㅐ": @"o", @"ㅔ": @"p",
            @"ㅁ": @"a", @"ㄴ": @"s", @"ㅇ": @"d", @"ㄹ": @"f", @"ㅎ": @"g",
            @"ㅋ": @"z", @"ㅌ": @"x", @"ㅊ": @"c", @"ㅍ": @"v", @"ㅠ": @"b",
            @"ㅜ": @"n", @"ㅡ": @"m"
        };
    });

    NSString *mapped = hangulToQwerty[trimmed];
    return mapped ?: trimmed;
}

static BOOL XCIsSupportedKeyString(NSString *raw) {
    NSString *key = XCNormalizeKeyString(raw);
    if (key.length == 0) {
        return YES;
    }
    if ([XCSupportedNamedKeys() containsObject:key]) {
        return YES;
    }
    if (key.length == 1) {
        unichar c = [key characterAtIndex:0];
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
            return YES;
        }
        if ([@"[]-=;',./`\\" containsString:key]) {
            return YES;
        }
    }
    return NO;
}

static NSTextField *XCWrappedLabel(NSString *text, NSRect frame, NSColor *color, NSFont *font) {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text ?: @"";
    label.editable = NO;
    label.bezeled = NO;
    label.bordered = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    label.textColor = color ?: NSColor.labelColor;
    label.font = font ?: [NSFont systemFontOfSize:13];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.usesSingleLineMode = NO;
    label.maximumNumberOfLines = 0;
    return label;
}

static NSDictionary *XCDefaultConfig(void) {
    return @{
        @"repeatDelayMilliseconds": @250,
        @"mappings": @{
            @"dpad_up": @{@"modifiers": @[], @"key": @"up"},
            @"dpad_down": @{@"modifiers": @[], @"key": @"down"},
            @"dpad_left": @{@"modifiers": @[], @"key": @"left"},
            @"dpad_right": @{@"modifiers": @[], @"key": @"right"},
            @"lb": @{@"modifiers": @[], @"key": @"scroll_down"},
            @"lt": @{@"modifiers": @[], @"key": @"scroll_up"},
            @"rb": @{@"modifiers": @[], @"key": @"space"},
            @"rt": @{@"modifiers": @[@"shift"], @"key": @"space"},
            @"y": @{@"modifiers": @[], @"key": @"pageup"},
            @"a": @{@"modifiers": @[], @"key": @"pagedown"},
            @"x": @{@"modifiers": @[@"command"], @"key": @"["},
            @"b": @{@"modifiers": @[@"command"], @"key": @"]"},
            @"view": @{@"modifiers": @[], @"key": @""},
            @"menu": @{@"modifiers": @[], @"key": @""},
            @"home": @{@"modifiers": @[], @"key": @""},
            @"l3": @{@"modifiers": @[], @"key": @""},
            @"r3": @{@"modifiers": @[], @"key": @""},
        }
    };
}

@interface XCConfigStore : NSObject
@property (nonatomic, readonly) NSString *configPath;
- (NSDictionary *)loadConfig;
- (void)saveConfig:(NSDictionary *)config;
@end

@implementation XCConfigStore

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        NSString *directory = [appSupport stringByAppendingPathComponent:XCAppName];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        _configPath = [directory stringByAppendingPathComponent:@"config.json"];
        [self migrateLegacyConfigIfNeeded];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_configPath]) {
            [self saveConfig:XCDefaultConfig()];
        }
    }
    return self;
}

- (void)migrateLegacyConfigIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.configPath]) {
        return;
    }

    NSString *bundleParent = [NSBundle mainBundle].bundlePath.stringByDeletingLastPathComponent;
    NSString *legacyPath = [bundleParent stringByAppendingPathComponent:@"config.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:legacyPath]) {
        [[NSFileManager defaultManager] copyItemAtPath:legacyPath toPath:self.configPath error:nil];
    }
}

- (NSDictionary *)loadConfig {
    NSData *data = [NSData dataWithContentsOfFile:self.configPath];
    if (data == nil) {
        return XCDefaultConfig();
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return XCDefaultConfig();
    }

    NSMutableDictionary *config = [XCDefaultConfig() mutableCopy];
    NSDictionary *loaded = (NSDictionary *)object;
    NSNumber *delay = loaded[@"repeatDelayMilliseconds"];
    if ([delay isKindOfClass:[NSNumber class]]) {
        config[@"repeatDelayMilliseconds"] = delay;
    }

    NSMutableDictionary *mappings = [config[@"mappings"] mutableCopy];
    NSDictionary *loadedMappings = loaded[@"mappings"];
    if ([loadedMappings isKindOfClass:[NSDictionary class]]) {
        for (NSString *button in XCButtonOrder()) {
            NSDictionary *mapping = loadedMappings[button];
            if ([mapping isKindOfClass:[NSDictionary class]]) {
                NSString *key = [mapping[@"key"] isKindOfClass:[NSString class]] ? mapping[@"key"] : @"";
                NSArray *modifiers = [mapping[@"modifiers"] isKindOfClass:[NSArray class]] ? mapping[@"modifiers"] : @[];
                mappings[button] = @{@"modifiers": modifiers, @"key": key};
            }
        }
    }

    config[@"mappings"] = mappings;
    return config;
}

- (void)saveConfig:(NSDictionary *)config {
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:self.configPath atomically:YES];
    XCLog(@"Saved config to %@", self.configPath);
}

@end

@interface XCShortcutEmitter : NSObject
- (BOOL)emitMapping:(NSDictionary *)mapping error:(NSError **)error;
@end

@implementation XCShortcutEmitter

- (BOOL)emitMapping:(NSDictionary *)mapping error:(NSError **)error {
    NSString *key = XCNormalizeKeyString(mapping[@"key"]);
    NSArray *modifiers = [mapping[@"modifiers"] isKindOfClass:[NSArray class]] ? mapping[@"modifiers"] : @[];

    if (key.length == 0) {
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
        return YES;
    }

    CGKeyCode keyCode = [self keyCodeForString:key error:error];
    if (keyCode == UINT16_MAX) {
        return NO;
    }

    CGEventFlags flags = [self flagsForModifiers:modifiers error:error];
    if (flags == UINT64_MAX) {
        return NO;
    }

    CGEventRef down = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef up = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    if (down == NULL || up == NULL) {
        if (down) CFRelease(down);
        if (up) CFRelease(up);
        return NO;
    }
    CGEventSetFlags(down, flags);
    CGEventSetFlags(up, flags);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    return YES;
}

- (CGEventFlags)flagsForModifiers:(NSArray *)modifiers error:(NSError **)error {
    CGEventFlags flags = 0;
    for (NSString *modifier in modifiers) {
        NSString *lower = modifier.lowercaseString;
        if ([lower isEqualToString:@"command"]) {
            flags |= kCGEventFlagMaskCommand;
        } else if ([lower isEqualToString:@"shift"]) {
            flags |= kCGEventFlagMaskShift;
        } else if ([lower isEqualToString:@"option"]) {
            flags |= kCGEventFlagMaskAlternate;
        } else if ([lower isEqualToString:@"control"]) {
            flags |= kCGEventFlagMaskControl;
        } else {
            if (error) {
                *error = [NSError errorWithDomain:@"Emitter" code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported modifier: %@", modifier]}];
            }
            return UINT64_MAX;
        }
    }
    return flags;
}

- (CGKeyCode)keyCodeForString:(NSString *)key error:(NSError **)error {
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
        return value.unsignedShortValue;
    }

    if (error) {
        *error = [NSError errorWithDomain:@"Emitter" code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported key: %@", key]}];
    }
    return UINT16_MAX;
}

@end

@interface XCControllerBridge : NSObject
@property (nonatomic, copy) void (^statusDidChange)(NSString *controllerName, BOOL active, BOOL accessibilityGranted);
@property (nonatomic, readonly) NSString *connectedControllerName;
@property (nonatomic, readonly) BOOL active;
@property (nonatomic, readonly) BOOL accessibilityGranted;
- (instancetype)initWithConfig:(NSDictionary *)config;
- (void)start;
- (void)updateConfig:(NSDictionary *)config;
- (void)setBridgeActive:(BOOL)active;
@end

@interface XCControllerBridge ()
@property (nonatomic, strong) NSDictionary *config;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *mappings;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *lastFireTimes;
@property (nonatomic, strong) XCShortcutEmitter *emitter;
@property (nonatomic, assign) NSTimeInterval repeatDelay;
@property (nonatomic, copy) NSString *connectedControllerName;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL accessibilityGranted;
@property (nonatomic, strong) NSMutableArray<GCExtendedGamepad *> *retainedProfiles;
@property (nonatomic, strong) NSMutableArray<GCControllerButtonInput *> *retainedButtons;
@end

@implementation XCControllerBridge

- (instancetype)initWithConfig:(NSDictionary *)config {
    self = [super init];
    if (self) {
        _emitter = [[XCShortcutEmitter alloc] init];
        _lastFireTimes = [NSMutableDictionary dictionary];
        _retainedProfiles = [NSMutableArray array];
        _retainedButtons = [NSMutableArray array];
        _active = YES;
        [self updateConfig:config];
    }
    return self;
}

- (void)start {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    self.accessibilityGranted = AXIsProcessTrusted();
    if (@available(macOS 11.3, *)) {
        GCController.shouldMonitorBackgroundEvents = YES;
    }

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(controllerDidConnect:) name:GCControllerDidConnectNotification object:nil];
    [center addObserver:self selector:@selector(controllerDidDisconnect:) name:GCControllerDidDisconnectNotification object:nil];

    for (GCController *controller in GCController.controllers) {
        [self registerController:controller];
    }

    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
    [self publishStatus];
}

- (void)updateConfig:(NSDictionary *)config {
    self.config = config ?: XCDefaultConfig();
    self.mappings = [self.config[@"mappings"] isKindOfClass:[NSDictionary class]] ? self.config[@"mappings"] : @{};
    NSNumber *delay = [self.config[@"repeatDelayMilliseconds"] isKindOfClass:[NSNumber class]] ? self.config[@"repeatDelayMilliseconds"] : @250;
    self.repeatDelay = delay.doubleValue / 1000.0;
    [self.lastFireTimes removeAllObjects];
}

- (void)setBridgeActive:(BOOL)active {
    _active = active;
    [self publishStatus];
}

- (void)controllerDidConnect:(NSNotification *)notification {
    GCController *controller = notification.object;
    if (controller) {
        [self registerController:controller];
    }
}

- (void)controllerDidDisconnect:(NSNotification *)notification {
    GCController *controller = notification.object;
    XCLog(@"Disconnected controller: %@", controller.vendorName ?: @"Unknown");
    self.connectedControllerName = GCController.controllers.firstObject.vendorName ?: @"Disconnected";
    [self publishStatus];
}

- (void)registerController:(GCController *)controller {
    GCExtendedGamepad *extended = controller.extendedGamepad;
    if (extended == nil) {
        return;
    }

    self.connectedControllerName = controller.vendorName ?: @"Unknown Controller";
    [self.retainedProfiles removeAllObjects];
    [self.retainedProfiles addObject:extended];
    [self.retainedButtons removeAllObjects];

    __weak typeof(self) weakSelf = self;
    extended.valueChangedHandler = ^(GCExtendedGamepad * _Nonnull gamepad, GCControllerElement * _Nonnull element) {
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
    [self bindButtonNamed:@"home" input:extended.buttonHome];

    [self publishStatus];
    XCLog(@"Connected controller: %@", self.connectedControllerName);
}

- (void)bindButtonNamed:(NSString *)buttonName input:(GCControllerButtonInput *)button {
    if (button == nil) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    button.valueChangedHandler = ^(GCControllerButtonInput * _Nonnull input, float value, BOOL pressed) {
        if (!pressed) {
            return;
        }
        XCLog(@"Direct button handler fired: %@ value=%.3f", buttonName, value);
        [weakSelf fireButton:buttonName];
    };
    [self.retainedButtons addObject:button];
}

- (void)handleElementChange:(GCControllerElement *)element onGamepad:(GCExtendedGamepad *)gamepad {
    NSDictionary<NSString *, id> *buttonMap = @{
        @"lb": gamepad.leftShoulder,
        @"rb": gamepad.rightShoulder,
        @"lt": gamepad.leftTrigger,
        @"rt": gamepad.rightTrigger,
        @"a": gamepad.buttonA,
        @"b": gamepad.buttonB,
        @"x": gamepad.buttonX,
        @"y": gamepad.buttonY,
        @"l3": gamepad.leftThumbstickButton ?: NSNull.null,
        @"r3": gamepad.rightThumbstickButton ?: NSNull.null,
        @"dpad_up": gamepad.dpad.up,
        @"dpad_down": gamepad.dpad.down,
        @"dpad_left": gamepad.dpad.left,
        @"dpad_right": gamepad.dpad.right,
        @"view": gamepad.buttonOptions ?: NSNull.null,
        @"menu": gamepad.buttonMenu ?: NSNull.null,
        @"home": gamepad.buttonHome ?: NSNull.null,
    };

    for (NSString *buttonName in buttonMap) {
        id candidate = buttonMap[buttonName];
        if (candidate == NSNull.null) {
            continue;
        }

        GCControllerButtonInput *button = (GCControllerButtonInput *)candidate;
        if (element == button && button.isPressed) {
            XCLog(@"Profile handler fired: %@", buttonName);
            [self fireButton:buttonName];
            break;
        }
    }
}

- (void)fireButton:(NSString *)buttonName {
    if (!self.active) {
        return;
    }

    NSDate *now = [NSDate date];
    NSDate *lastDate = self.lastFireTimes[buttonName];
    if (lastDate != nil && [now timeIntervalSinceDate:lastDate] < self.repeatDelay) {
        return;
    }
    self.lastFireTimes[buttonName] = now;

    NSDictionary *mapping = self.mappings[buttonName];
    if (![mapping isKindOfClass:[NSDictionary class]]) {
        return;
    }

    XCLog(@"Emitting button %@ with mapping %@", buttonName, mapping);
    NSError *error = nil;
    if (![self.emitter emitMapping:mapping error:&error]) {
        XCLog(@"Failed to emit %@: %@", buttonName, error.localizedDescription);
    }
}

- (void)publishStatus {
    if (self.statusDidChange) {
        self.statusDidChange(self.connectedControllerName ?: @"No Controller", self.active, self.accessibilityGranted);
    }
}

@end

typedef NS_ENUM(NSInteger, XCActionType) {
    XCActionTypeNone = 0,
    XCActionTypeKey = 1,
    XCActionTypeShortcut = 2,
    XCActionTypeScrollUp = 3,
    XCActionTypeScrollDown = 4,
};

@interface XCButtonMappingRowView : NSView <NSTextFieldDelegate>
@property (nonatomic, copy) NSString *buttonName;
@property (nonatomic, copy) void (^onChange)(NSString *buttonName, NSDictionary *mapping);
- (instancetype)initWithButtonName:(NSString *)buttonName mapping:(NSDictionary *)mapping;
- (void)applyMapping:(NSDictionary *)mapping;
@end

@interface XCButtonMappingRowView ()
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSPopUpButton *actionPopup;
@property (nonatomic, strong) NSTextField *keyField;
@property (nonatomic, strong) NSButton *commandCheck;
@property (nonatomic, strong) NSButton *shiftCheck;
@property (nonatomic, strong) NSButton *optionCheck;
@property (nonatomic, strong) NSButton *controlCheck;
@property (nonatomic, strong) NSTextField *statusLabel;
@end

@implementation XCButtonMappingRowView

- (instancetype)initWithButtonName:(NSString *)buttonName mapping:(NSDictionary *)mapping {
    self = [super initWithFrame:NSMakeRect(0, 0, 840, 36)];
    if (self) {
        self.buttonName = buttonName;
        [self buildUI];
        [self applyMapping:mapping];
    }
    return self;
}

- (void)buildUI {
    self.titleLabel = [NSTextField labelWithString:XCButtonDisplayName(self.buttonName)];
    self.titleLabel.frame = NSMakeRect(14, 8, 120, 20);
    [self addSubview:self.titleLabel];

    self.actionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(136, 4, 150, 28) pullsDown:NO];
    [self.actionPopup addItemsWithTitles:@[@"None", @"Key", @"Shortcut", @"Scroll Up", @"Scroll Down"]];
    self.actionPopup.target = self;
    self.actionPopup.action = @selector(controlChanged:);
    [self addSubview:self.actionPopup];

    self.keyField = [[NSTextField alloc] initWithFrame:NSMakeRect(296, 5, 170, 24)];
    self.keyField.placeholderString = @"key (a, up, pageup)";
    self.keyField.target = self;
    self.keyField.action = @selector(controlChanged:);
    self.keyField.delegate = self;
    [self addSubview:self.keyField];

    self.commandCheck = [self checkboxWithTitle:@"Cmd" x:480];
    self.shiftCheck = [self checkboxWithTitle:@"Shift" x:548];
    self.optionCheck = [self checkboxWithTitle:@"Opt" x:620];
    self.controlCheck = [self checkboxWithTitle:@"Ctrl" x:688];

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.frame = NSMakeRect(760, 8, 58, 20);
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.alignment = NSTextAlignmentRight;
    [self addSubview:self.statusLabel];
}

- (NSButton *)checkboxWithTitle:(NSString *)title x:(CGFloat)x {
    NSButton *checkbox = [[NSButton alloc] initWithFrame:NSMakeRect(x, 7, 64, 22)];
    checkbox.buttonType = NSButtonTypeSwitch;
    checkbox.title = title;
    checkbox.target = self;
    checkbox.action = @selector(controlChanged:);
    [self addSubview:checkbox];
    return checkbox;
}

- (void)applyMapping:(NSDictionary *)mapping {
    NSString *key = XCNormalizeKeyString(mapping[@"key"]);
    NSArray *modifiers = [mapping[@"modifiers"] isKindOfClass:[NSArray class]] ? mapping[@"modifiers"] : @[];

    XCActionType type = XCActionTypeNone;
    if ([key isEqualToString:@"scroll_up"]) {
        type = XCActionTypeScrollUp;
    } else if ([key isEqualToString:@"scroll_down"]) {
        type = XCActionTypeScrollDown;
    } else if (key.length == 0) {
        type = XCActionTypeNone;
    } else if (modifiers.count == 0) {
        type = XCActionTypeKey;
    } else {
        type = XCActionTypeShortcut;
    }

    [self.actionPopup selectItemAtIndex:type];
    self.keyField.stringValue = (type == XCActionTypeKey || type == XCActionTypeShortcut) ? key : @"";
    self.commandCheck.state = [modifiers containsObject:@"command"] ? NSControlStateValueOn : NSControlStateValueOff;
    self.shiftCheck.state = [modifiers containsObject:@"shift"] ? NSControlStateValueOn : NSControlStateValueOff;
    self.optionCheck.state = [modifiers containsObject:@"option"] ? NSControlStateValueOn : NSControlStateValueOff;
    self.controlCheck.state = [modifiers containsObject:@"control"] ? NSControlStateValueOn : NSControlStateValueOff;
    [self refreshEnabledState];
    [self refreshValidationState];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    [self controlChanged:notification.object];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self controlChanged:notification.object];
}

- (void)controlChanged:(id)sender {
    [self refreshEnabledState];
    [self refreshValidationState];
    if (self.onChange) {
        self.onChange(self.buttonName, [self currentMapping]);
    }
}

- (void)refreshEnabledState {
    XCActionType type = (XCActionType)self.actionPopup.indexOfSelectedItem;
    BOOL usesKey = (type == XCActionTypeKey || type == XCActionTypeShortcut);
    BOOL usesModifiers = (type == XCActionTypeShortcut);
    self.keyField.enabled = usesKey;
    self.commandCheck.enabled = usesModifiers;
    self.shiftCheck.enabled = usesModifiers;
    self.optionCheck.enabled = usesModifiers;
    self.controlCheck.enabled = usesModifiers;
}

- (void)refreshValidationState {
    XCActionType type = (XCActionType)self.actionPopup.indexOfSelectedItem;
    BOOL requiresKey = (type == XCActionTypeKey || type == XCActionTypeShortcut);
    NSString *normalized = XCNormalizeKeyString(self.keyField.stringValue);
    BOOL valid = XCIsSupportedKeyString(normalized);

    if (requiresKey && normalized.length > 0 && !valid) {
        self.statusLabel.stringValue = @"Invalid";
        self.statusLabel.textColor = NSColor.systemRedColor;
        self.keyField.layer.borderWidth = 1.0;
        self.keyField.layer.borderColor = NSColor.systemRedColor.CGColor;
        self.keyField.wantsLayer = YES;
        self.keyField.toolTip = @"Use a-z, 0-9, punctuation like [ ], or named keys like up, down, pageup, pagedown, return, and space.";
    } else {
        self.statusLabel.stringValue = requiresKey && normalized.length > 0 ? @"OK" : @"";
        self.statusLabel.textColor = NSColor.secondaryLabelColor;
        self.keyField.layer.borderWidth = 0;
        self.keyField.toolTip = @"Hangul keyboard input is normalized to the matching QWERTY key.";
    }
}

- (NSDictionary *)currentMapping {
    XCActionType type = (XCActionType)self.actionPopup.indexOfSelectedItem;
    switch (type) {
        case XCActionTypeNone:
            return @{@"modifiers": @[], @"key": @""};
        case XCActionTypeScrollUp:
            return @{@"modifiers": @[], @"key": @"scroll_up"};
        case XCActionTypeScrollDown:
            return @{@"modifiers": @[], @"key": @"scroll_down"};
        case XCActionTypeKey: {
            NSString *normalizedKey = XCNormalizeKeyString(self.keyField.stringValue);
            if (![self.keyField.stringValue isEqualToString:normalizedKey]) {
                self.keyField.stringValue = normalizedKey;
            }
            return @{@"modifiers": @[], @"key": normalizedKey};
        }
        case XCActionTypeShortcut: {
            NSMutableArray *modifiers = [NSMutableArray array];
            if (self.commandCheck.state == NSControlStateValueOn) [modifiers addObject:@"command"];
            if (self.shiftCheck.state == NSControlStateValueOn) [modifiers addObject:@"shift"];
            if (self.optionCheck.state == NSControlStateValueOn) [modifiers addObject:@"option"];
            if (self.controlCheck.state == NSControlStateValueOn) [modifiers addObject:@"control"];
            NSString *normalizedKey = XCNormalizeKeyString(self.keyField.stringValue);
            if (![self.keyField.stringValue isEqualToString:normalizedKey]) {
                self.keyField.stringValue = normalizedKey;
            }
            return @{@"modifiers": modifiers, @"key": normalizedKey};
        }
    }
}

@end

@interface XCSettingsWindowController : NSWindowController
@property (nonatomic, copy) NSDictionary *(^configProvider)(void);
@property (nonatomic, copy) void (^configDidChange)(NSDictionary *config);
- (instancetype)initWithConfig:(NSDictionary *)config;
- (void)reloadWithConfig:(NSDictionary *)config;
@end

@interface XCSettingsWindowController ()
@property (nonatomic, strong) NSMutableDictionary *workingConfig;
@property (nonatomic, strong) NSMutableDictionary<NSString *, XCButtonMappingRowView *> *rowViews;
@property (nonatomic, strong) NSTextField *repeatDelayField;
@property (nonatomic, strong) NSTextField *configPathLabel;
@end

@implementation XCSettingsWindowController

- (instancetype)initWithConfig:(NSDictionary *)config {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 920, 720)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        self.window.title = @"Xbox Controller Shortcuts Settings";
        self.rowViews = [NSMutableDictionary dictionary];
        [self buildUI];
        [self reloadWithConfig:config];
    }
    return self;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    NSTextField *title = [NSTextField labelWithString:@"Button Mapping"];
    title.font = [NSFont boldSystemFontOfSize:22];
    title.frame = NSMakeRect(24, 670, 320, 28);
    [content addSubview:title];

    NSBox *infoBox = [[NSBox alloc] initWithFrame:NSMakeRect(24, 548, 872, 102)];
    infoBox.boxType = NSBoxCustom;
    infoBox.transparent = NO;
    infoBox.borderWidth = 0;
    infoBox.fillColor = [NSColor colorWithWhite:0.96 alpha:1.0];
    infoBox.cornerRadius = 10.0;
    [content addSubview:infoBox];

    NSTextField *hint = XCWrappedLabel(@"Enter a plain key like a, b, [, ], up, down, pageup, pagedown, return, or space. For shortcuts, choose Shortcut and add modifiers such as Cmd or Shift.", NSMakeRect(16, 60, 840, 32), NSColor.labelColor, [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]);
    [infoBox addSubview:hint];

    NSTextField *subHint = XCWrappedLabel(@"If you use a non-English keyboard layout or input method, typed characters are normalized to the matching physical QWERTY key when possible.", NSMakeRect(16, 34, 840, 22), NSColor.secondaryLabelColor, [NSFont systemFontOfSize:12]);
    [infoBox addSubview:subHint];

    NSTextField *koreanHint = XCWrappedLabel(@"한글 등 영문이 아닌 입력 상태에서도 가능하면 같은 위치의 QWERTY 키로 자동 보정됩니다. 단축키를 만들려면 Shortcut을 선택한 뒤 Cmd, Shift 같은 수정 키를 함께 지정하세요.", NSMakeRect(16, 10, 840, 22), NSColor.secondaryLabelColor, [NSFont systemFontOfSize:12]);
    [infoBox addSubview:koreanHint];

    NSTextField *repeatLabel = [NSTextField labelWithString:@"Repeat delay (ms)"];
    repeatLabel.frame = NSMakeRect(24, 510, 110, 20);
    [content addSubview:repeatLabel];

    self.repeatDelayField = [[NSTextField alloc] initWithFrame:NSMakeRect(144, 506, 80, 26)];
    self.repeatDelayField.target = self;
    self.repeatDelayField.action = @selector(repeatDelayChanged:);
    [content addSubview:self.repeatDelayField];

    NSButton *resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(240, 503, 132, 30)];
    resetButton.title = @"Reset Defaults";
    resetButton.bezelStyle = NSBezelStyleRounded;
    resetButton.target = self;
    resetButton.action = @selector(resetDefaults:);
    [content addSubview:resetButton];

    NSTextField *headerButton = [NSTextField labelWithString:@"Button"];
    headerButton.frame = NSMakeRect(38, 476, 90, 16);
    headerButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    headerButton.textColor = NSColor.secondaryLabelColor;
    [content addSubview:headerButton];

    NSTextField *headerAction = [NSTextField labelWithString:@"Action"];
    headerAction.frame = NSMakeRect(164, 476, 90, 16);
    headerAction.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    headerAction.textColor = NSColor.secondaryLabelColor;
    [content addSubview:headerAction];

    NSTextField *headerKey = [NSTextField labelWithString:@"Key"];
    headerKey.frame = NSMakeRect(322, 476, 90, 16);
    headerKey.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    headerKey.textColor = NSColor.secondaryLabelColor;
    [content addSubview:headerKey];

    NSTextField *headerModifiers = [NSTextField labelWithString:@"Modifiers"];
    headerModifiers.frame = NSMakeRect(486, 476, 120, 16);
    headerModifiers.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    headerModifiers.textColor = NSColor.secondaryLabelColor;
    [content addSubview:headerModifiers];

    NSTextField *headerState = [NSTextField labelWithString:@"State"];
    headerState.frame = NSMakeRect(808, 476, 60, 16);
    headerState.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    headerState.textColor = NSColor.secondaryLabelColor;
    [content addSubview:headerState];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 82, 872, 384)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    [content addSubview:scrollView];

    NSView *documentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 840, XCButtonOrder().count * 40 + 20)];
    scrollView.documentView = documentView;

    CGFloat y = documentView.frame.size.height - 42;
    for (NSString *buttonName in XCButtonOrder()) {
        XCButtonMappingRowView *row = [[XCButtonMappingRowView alloc] initWithButtonName:buttonName mapping:@{@"modifiers": @[], @"key": @""}];
        row.frame = NSMakeRect(0, y, 840, 36);
        __weak typeof(self) weakSelf = self;
        row.onChange = ^(NSString *name, NSDictionary *mapping) {
            [weakSelf mappingChangedForButton:name mapping:mapping];
        };
        [documentView addSubview:row];
        self.rowViews[buttonName] = row;
        y -= 40;
    }

    self.configPathLabel = [NSTextField labelWithString:@""];
    self.configPathLabel.textColor = NSColor.secondaryLabelColor;
    self.configPathLabel.frame = NSMakeRect(24, 34, 872, 18);
    self.configPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.configPathLabel.toolTip = @"The config file used by the app.";
    [content addSubview:self.configPathLabel];
}

- (void)reloadWithConfig:(NSDictionary *)config {
    self.workingConfig = [config mutableCopy] ?: [XCDefaultConfig() mutableCopy];
    NSDictionary *mappings = self.workingConfig[@"mappings"];
    for (NSString *buttonName in XCButtonOrder()) {
        [self.rowViews[buttonName] applyMapping:mappings[buttonName] ?: @{@"modifiers": @[], @"key": @""}];
    }
    NSNumber *delay = [self.workingConfig[@"repeatDelayMilliseconds"] isKindOfClass:[NSNumber class]] ? self.workingConfig[@"repeatDelayMilliseconds"] : @250;
    self.repeatDelayField.stringValue = delay.stringValue;
}

- (void)mappingChangedForButton:(NSString *)buttonName mapping:(NSDictionary *)mapping {
    NSMutableDictionary *config = [self.workingConfig mutableCopy];
    NSMutableDictionary *mappings = [config[@"mappings"] mutableCopy];
    mappings[buttonName] = mapping;
    config[@"mappings"] = mappings;
    self.workingConfig = config;
    if (self.configDidChange) {
        self.configDidChange(self.workingConfig);
    }
}

- (void)repeatDelayChanged:(id)sender {
    NSInteger value = self.repeatDelayField.integerValue;
    if (value < 0) value = 0;
    NSMutableDictionary *config = [self.workingConfig mutableCopy];
    config[@"repeatDelayMilliseconds"] = @(value);
    self.workingConfig = config;
    if (self.configDidChange) {
        self.configDidChange(self.workingConfig);
    }
}

- (void)resetDefaults:(id)sender {
    NSDictionary *defaults = XCDefaultConfig();
    [self reloadWithConfig:defaults];
    if (self.configDidChange) {
        self.configDidChange(defaults);
    }
}

@end

@interface XCAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenuItem *connectionItem;
@property (nonatomic, strong) NSMenuItem *activeItem;
@property (nonatomic, strong) NSMenuItem *toggleItem;
@property (nonatomic, strong) NSMenuItem *accessibilityItem;
@property (nonatomic, strong) XCConfigStore *configStore;
@property (nonatomic, strong) XCControllerBridge *bridge;
@property (nonatomic, strong) XCSettingsWindowController *settingsWindowController;
@property (nonatomic, strong) NSDictionary *currentConfig;
@property (nonatomic, strong) NSWindowController *aboutWindowController;
@end

@implementation XCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    XCLog(@"App launched");
    self.configStore = [[XCConfigStore alloc] init];
    self.currentConfig = [self.configStore loadConfig];
    self.bridge = [[XCControllerBridge alloc] initWithConfig:self.currentConfig];
    __weak typeof(self) weakSelf = self;
    self.bridge.statusDidChange = ^(NSString *controllerName, BOOL active, BOOL accessibilityGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updateMenuWithControllerName:controllerName active:active accessibilityGranted:accessibilityGranted];
        });
    };
    [self buildStatusMenu];
    [self buildSettingsWindow];
    [self.bridge start];
    [self updateMenuWithControllerName:@"No Controller" active:YES accessibilityGranted:self.bridge.accessibilityGranted];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self openSettings:nil];
    return YES;
}

- (void)buildStatusMenu {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"XCS";
    self.statusItem.button.toolTip = @"Xbox Controller Shortcuts";

    NSMenu *menu = [[NSMenu alloc] initWithTitle:XCAppName];
    self.connectionItem = [[NSMenuItem alloc] initWithTitle:@"Connected: No Controller" action:nil keyEquivalent:@""];
    self.connectionItem.enabled = NO;
    [menu addItem:self.connectionItem];

    self.activeItem = [[NSMenuItem alloc] initWithTitle:@"Mapping: On" action:nil keyEquivalent:@""];
    self.activeItem.enabled = NO;
    [menu addItem:self.activeItem];

    self.accessibilityItem = [[NSMenuItem alloc] initWithTitle:@"Accessibility: Unknown" action:nil keyEquivalent:@""];
    self.accessibilityItem.enabled = NO;
    [menu addItem:self.accessibilityItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *openSettings = [[NSMenuItem alloc] initWithTitle:@"Open Settings" action:@selector(openSettings:) keyEquivalent:@","];
    openSettings.target = self;
    [menu addItem:openSettings];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About Xbox Controller Shortcuts" action:@selector(openAbout:) keyEquivalent:@""];
    aboutItem.target = self;
    [menu addItem:aboutItem];

    self.toggleItem = [[NSMenuItem alloc] initWithTitle:@"Pause Mapping" action:@selector(toggleMapping:) keyEquivalent:@""];
    self.toggleItem.target = self;
    [menu addItem:self.toggleItem];

    NSMenuItem *openAccessibility = [[NSMenuItem alloc] initWithTitle:@"Open Accessibility Settings" action:@selector(openAccessibilitySettings:) keyEquivalent:@""];
    openAccessibility.target = self;
    [menu addItem:openAccessibility];

    NSMenuItem *openInputMonitoring = [[NSMenuItem alloc] initWithTitle:@"Open Input Monitoring Settings" action:@selector(openInputMonitoringSettings:) keyEquivalent:@""];
    openInputMonitoring.target = self;
    [menu addItem:openInputMonitoring];

    NSMenuItem *openLog = [[NSMenuItem alloc] initWithTitle:@"Open Log" action:@selector(openLog:) keyEquivalent:@""];
    openLog.target = self;
    [menu addItem:openLog];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (void)buildSettingsWindow {
    self.settingsWindowController = [[XCSettingsWindowController alloc] initWithConfig:self.currentConfig];
    __weak typeof(self) weakSelf = self;
    self.settingsWindowController.configDidChange = ^(NSDictionary *config) {
        weakSelf.currentConfig = config;
        [weakSelf.configStore saveConfig:config];
        [weakSelf.bridge updateConfig:config];
    };
    self.settingsWindowController.configPathLabel.stringValue = [NSString stringWithFormat:@"Config saved at %@", self.configStore.configPath];
}

- (void)updateMenuWithControllerName:(NSString *)controllerName active:(BOOL)active accessibilityGranted:(BOOL)accessibilityGranted {
    self.connectionItem.title = [NSString stringWithFormat:@"Connected: %@", controllerName ?: @"No Controller"];
    self.activeItem.title = [NSString stringWithFormat:@"Mapping: %@%@", active ? @"On" : @"Paused", accessibilityGranted ? @"" : @" (Accessibility Needed)"];
    self.accessibilityItem.title = [NSString stringWithFormat:@"Accessibility: %@", accessibilityGranted ? @"Granted" : @"Needed"];
    self.toggleItem.title = active ? @"Pause Mapping" : @"Resume Mapping";
}

- (void)openSettings:(id)sender {
    [self.settingsWindowController reloadWithConfig:self.currentConfig];
    [self.settingsWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openAbout:(id)sender {
    if (self.aboutWindowController == nil) {
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 250)
                                                       styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.title = @"About Xbox Controller Shortcuts";
        window.releasedWhenClosed = NO;

        NSView *content = window.contentView;

        NSTextField *title = [NSTextField labelWithString:@"Xbox Controller Shortcuts"];
        title.font = [NSFont boldSystemFontOfSize:24];
        title.frame = NSMakeRect(28, 184, 320, 30);
        [content addSubview:title];

        NSTextField *subtitle = XCWrappedLabel(@"A macOS menu bar app for mapping Xbox controller buttons to keys, shortcuts, and scroll actions.", NSMakeRect(28, 136, 360, 40), NSColor.secondaryLabelColor, [NSFont systemFontOfSize:13]);
        [content addSubview:subtitle];

        NSString *version = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0";
        NSTextField *versionLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Version %@", version]];
        versionLabel.textColor = NSColor.secondaryLabelColor;
        versionLabel.frame = NSMakeRect(28, 108, 120, 18);
        [content addSubview:versionLabel];

        NSTextField *configLabel = XCWrappedLabel([NSString stringWithFormat:@"Config: %@", self.configStore.configPath], NSMakeRect(28, 62, 360, 34), NSColor.secondaryLabelColor, [NSFont systemFontOfSize:12]);
        configLabel.toolTip = self.configStore.configPath;
        [content addSubview:configLabel];

        NSTextField *licenseLabel = [NSTextField labelWithString:@"Requires Accessibility and Input Monitoring permission"];
        licenseLabel.textColor = NSColor.secondaryLabelColor;
        licenseLabel.frame = NSMakeRect(28, 40, 320, 18);
        [content addSubview:licenseLabel];

        NSButton *repoButton = [[NSButton alloc] initWithFrame:NSMakeRect(28, 12, 180, 24)];
        repoButton.title = @"Open GitHub Repository";
        repoButton.bezelStyle = NSBezelStyleRounded;
        repoButton.target = self;
        repoButton.action = @selector(openRepository:);
        [content addSubview:repoButton];

        self.aboutWindowController = [[NSWindowController alloc] initWithWindow:window];
    }

    [self.aboutWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)toggleMapping:(id)sender {
    [self.bridge setBridgeActive:!self.bridge.active];
}

- (void)openLog:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:XCLogPath()]];
}

- (void)openAccessibilitySettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openInputMonitoringSettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"];
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openRepository:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/slightlytweaked/Xbox-Controller-Shortcuts"];
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)quitApp:(id)sender {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        XCAppDelegate *delegate = [[XCAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
