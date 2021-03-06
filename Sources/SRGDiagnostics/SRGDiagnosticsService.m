//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGDiagnosticsService.h"

#import "NSTimer+SRGDiagnostics.h"
#import "SRGDiagnosticReport+Private.h"

static NSMutableDictionary<NSString *, SRGDiagnosticsService *> *s_diagnosticsServices;

@interface SRGDiagnosticsService ()

@property (nonatomic) NSMutableDictionary<NSString *, SRGDiagnosticReport *> *reports;
@property (nonatomic) NSMutableArray<SRGDiagnosticReport *> *finishedReports;

@property (nonatomic) NSTimer *timer;
@property (nonatomic, getter=isSubmitting) BOOL submitting;

@end

@implementation SRGDiagnosticsService

#pragma mark Class methods

+ (SRGDiagnosticsService *)serviceWithName:(NSString *)name
{
    @synchronized(s_diagnosticsServices) {
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_diagnosticsServices = [NSMutableDictionary dictionary];
        });
        
        SRGDiagnosticsService *diagnosticsService = s_diagnosticsServices[name];
        if (! diagnosticsService) {
            diagnosticsService = [[SRGDiagnosticsService alloc] init];
            s_diagnosticsServices[name] = diagnosticsService;
        }
        return diagnosticsService;
    }
}

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.reports = [NSMutableDictionary dictionary];
        self.finishedReports = [NSMutableArray array];
        self.submissionInterval = SRGDiagnosticsDefaultSubmissionInterval;
    }
    return self;
}

#pragma mark Getters and setters

- (void)setSubmissionBlock:(void (^)(NSDictionary * _Nonnull, void (^ _Nonnull)(BOOL)))submissionBlock
{
    @synchronized(self) {
        _submissionBlock = [submissionBlock copy];
    }
}

- (void)setSubmissionInterval:(NSTimeInterval)submissionInterval
{
    if (submissionInterval < SRGDiagnosticsMinimumSubmissionInterval) {
        submissionInterval = SRGDiagnosticsMinimumSubmissionInterval;
    }
    
    _submissionInterval = submissionInterval;
    
    __weak __typeof(self) weakSelf = self;
    self.timer = [NSTimer srgdiagnostics_timerWithTimeInterval:submissionInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf submitFinishedReports];
    }];
}

- (void)setTimer:(NSTimer *)timer
{
    [_timer invalidate];
    _timer = timer;
}

#pragma mark Reports

- (SRGDiagnosticReport *)reportWithName:(NSString *)name
{
    @synchronized(self) {
        SRGDiagnosticReport *report = self.reports[name];
        if (! report) {
            report = [[SRGDiagnosticReport alloc] initWithDiagnosticsService:self];
            self.reports[name] = report;
        }
        return report;
    }
}

#pragma mark Submission

- (void)prepareToSubmitReport:(SRGDiagnosticReport *)report
{
    @synchronized(self) {
        NSString *identifier = [self.reports allKeysForObject:report].firstObject;
        if (identifier) {
            [self.reports removeObjectForKey:identifier];
            [self.finishedReports addObject:report.copy];
        }
    }
}

- (void)discardReport:(SRGDiagnosticReport *)report
{
    @synchronized (self) {
        NSString *identifier = [self.reports allKeysForObject:report].firstObject;
        if (identifier) {
            [self.reports removeObjectForKey:identifier];
        }
    }
}

- (void)submitFinishedReports
{
    @synchronized(self) {
        if (self.submitting) {
            return;
        }
        
        if (self.finishedReports.count == 0) {
            return;
        }
        
        self.submitting = YES;
        
        __block NSUInteger processedReports = 0;
        NSArray<SRGDiagnosticReport *> *finishedReports = self.finishedReports.copy;
        for (SRGDiagnosticReport *report in finishedReports) {
            void (^completionBlock)(BOOL) = ^(BOOL success) {
                @synchronized(self) {
                    if (success) {
                        [self.finishedReports removeObject:report];
                    }
                    
                    ++processedReports;
                    if (processedReports == finishedReports.count) {
                        self.submitting = NO;
                    }
                }
            };
            
            if (self.submissionBlock) {
                self.submissionBlock([report JSONDictionary], completionBlock);
            }
            else {
                completionBlock(YES);
            }
        }
    }
}

@end
