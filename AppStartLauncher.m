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
        NSString *runScript = [projectRoot stringByAppendingPathComponent:@"run.sh"];
        NSString *config = [projectRoot stringByAppendingPathComponent:@"config.json"];

        AppendLog([NSString stringWithFormat:@"Start app invoked. projectRoot=%@", projectRoot]);

        if (![NSFileManager.defaultManager isExecutableFileAtPath:runScript]) {
            AppendLog([NSString stringWithFormat:@"run.sh is missing or not executable: %@", runScript]);
            return 1;
        }

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/zsh";
        task.arguments = @[runScript, config];

        NSString *stdoutPath = [projectRoot stringByAppendingPathComponent:@"app-launch.log"];
        NSFileHandle *outHandle = [NSFileHandle fileHandleForWritingAtPath:stdoutPath];
        if (outHandle == nil) {
            [[NSData data] writeToFile:stdoutPath atomically:YES];
            outHandle = [NSFileHandle fileHandleForWritingAtPath:stdoutPath];
        }
        [outHandle seekToEndOfFile];
        task.standardOutput = outHandle;
        task.standardError = outHandle;

        @try {
            [task launch];
            AppendLog([NSString stringWithFormat:@"Launched task pid=%d", task.processIdentifier]);
        } @catch (NSException *exception) {
            AppendLog([NSString stringWithFormat:@"Launch failed: %@", exception.reason]);
            return 1;
        }
    }
    return 0;
}
