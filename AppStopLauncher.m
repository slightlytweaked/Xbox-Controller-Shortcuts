#import <Foundation/Foundation.h>

static NSString *ProjectRoot(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    return [bundlePath stringByDeletingLastPathComponent];
}

static void AppendLog(NSString *message) {
    NSString *projectRoot = ProjectRoot();
    NSString *logPath = [projectRoot stringByAppendingPathComponent:@"app-launch.log"];
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:logPath]) {
        [line writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *projectRoot = ProjectRoot();
        NSString *binary = [projectRoot stringByAppendingPathComponent:@"xbox-controller-shortcuts"];
        AppendLog([NSString stringWithFormat:@"Stop app invoked. binary=%@", binary]);

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/pkill";
        task.arguments = @[@"-f", binary];

        @try {
            [task launch];
        } @catch (NSException *exception) {
            AppendLog([NSString stringWithFormat:@"Stop launch failed: %@", exception.reason]);
            return 1;
        }
    }
    return 0;
}
