#import <Cocoa/Cocoa.h>

typedef NS_OPTIONS(NSUInteger, MDCReason) {
    MDCReasonTemporary = 1 << 0,
    MDCReasonLarge = 1 << 1,
};

static NSString * const MDCNameColumn = @"name";
static NSString * const MDCReasonColumn = @"reason";
static NSString * const MDCSizeColumn = @"size";
static NSString * const MDCModifiedColumn = @"modified";
static NSString * const MDCPathColumn = @"path";
static NSString * const MDCSelectionColumn = @"selected";

static NSString *MDCFormatBytes(unsigned long long value) {
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.allowedUnits = NSByteCountFormatterUseKB | NSByteCountFormatterUseMB | NSByteCountFormatterUseGB | NSByteCountFormatterUseTB;
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    formatter.includesUnit = YES;
    formatter.adaptive = YES;
    return [formatter stringFromByteCount:(long long)value];
}

static NSString *MDCFormatDate(NSDate *date) {
    if (date == nil) {
        return @"Unknown";
    }

    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    });

    return [formatter stringFromDate:date];
}

@interface MDCFileItem : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) MDCReason reasons;
@property (nonatomic, assign) unsigned long long sizeInBytes;
@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *rootLabels;
@property (nonatomic, assign) BOOL selected;

- (instancetype)initWithURL:(NSURL *)url
                    reasons:(MDCReason)reasons
                sizeInBytes:(unsigned long long)sizeInBytes
               modifiedDate:(NSDate *)modifiedDate
                  rootLabel:(NSString *)rootLabel;
- (void)mergeReason:(MDCReason)reason
        sizeInBytes:(unsigned long long)sizeInBytes
       modifiedDate:(NSDate *)modifiedDate
          rootLabel:(NSString *)rootLabel;
- (BOOL)matchesQuery:(NSString *)query allowedReasons:(MDCReason)allowedReasons;
- (NSString *)reasonSummary;
- (NSString *)rootSummary;

@end

@implementation MDCFileItem

- (instancetype)initWithURL:(NSURL *)url
                    reasons:(MDCReason)reasons
                sizeInBytes:(unsigned long long)sizeInBytes
               modifiedDate:(NSDate *)modifiedDate
                  rootLabel:(NSString *)rootLabel {
    self = [super init];
    if (self) {
        _url = url;
        _reasons = reasons;
        _sizeInBytes = sizeInBytes;
        _modifiedDate = modifiedDate;
        _rootLabels = [[NSMutableOrderedSet alloc] init];
        if (rootLabel.length > 0) {
            [_rootLabels addObject:rootLabel];
        }
        _selected = NO;
    }
    return self;
}

- (void)mergeReason:(MDCReason)reason
        sizeInBytes:(unsigned long long)sizeInBytes
       modifiedDate:(NSDate *)modifiedDate
          rootLabel:(NSString *)rootLabel {
    self.reasons |= reason;
    if (sizeInBytes > self.sizeInBytes) {
        self.sizeInBytes = sizeInBytes;
    }
    if (modifiedDate != nil && (self.modifiedDate == nil || [modifiedDate compare:self.modifiedDate] == NSOrderedDescending)) {
        self.modifiedDate = modifiedDate;
    }
    if (rootLabel.length > 0) {
        [self.rootLabels addObject:rootLabel];
    }
}

- (BOOL)matchesQuery:(NSString *)query allowedReasons:(MDCReason)allowedReasons {
    if ((self.reasons & allowedReasons) == 0) {
        return NO;
    }

    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return YES;
    }

    NSString *haystack = [@[self.url.lastPathComponent ?: @"",
                            self.url.path ?: @"",
                            [self rootSummary] ?: @""]
                          componentsJoinedByString:@" "].lowercaseString;
    return [haystack containsString:trimmed.lowercaseString];
}

- (NSString *)reasonSummary {
    NSMutableArray<NSString *> *parts = [[NSMutableArray alloc] init];
    if ((self.reasons & MDCReasonTemporary) != 0) {
        [parts addObject:@"Temp"];
    }
    if ((self.reasons & MDCReasonLarge) != 0) {
        [parts addObject:@"Large"];
    }
    return [parts componentsJoinedByString:@", "];
}

- (NSString *)rootSummary {
    return [self.rootLabels.array componentsJoinedByString:@" • "];
}

@end

@interface MDCAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSTextFieldDelegate>

@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *tempToggle;
@property (nonatomic, strong) NSButton *largeToggle;
@property (nonatomic, strong) NSTextField *thresholdField;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *tempSummaryLabel;
@property (nonatomic, strong) NSTextField *largeSummaryLabel;
@property (nonatomic, strong) NSTextField *selectedSummaryLabel;
@property (nonatomic, strong) NSTextView *warningsView;

@property (nonatomic, strong) NSMutableArray<MDCFileItem *> *allItems;
@property (nonatomic, strong) NSMutableArray<MDCFileItem *> *visibleItems;
@property (nonatomic, strong) NSMutableArray<NSString *> *warnings;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, assign) BOOL isTrashing;

@end

@implementation MDCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.allItems = [[NSMutableArray alloc] init];
    self.visibleItems = [[NSMutableArray alloc] init];
    self.warnings = [[NSMutableArray alloc] init];
    [self buildMainMenu];
    [self buildUI];
    [self rescan:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    if (!flag) {
        [self.window makeKeyAndOrderFront:nil];
    } else {
        [self.window orderFront:nil];
    }
    [NSApp unhide:nil];
    [NSApp activateIgnoringOtherApps:YES];
    return YES;
}

- (void)buildUI {
    NSRect frame = NSMakeRect(0, 0, 1180, 780);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Mac Drive Cleaner";
    [self.window center];

    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;

    NSTextField *titleLabel = [self labelWithString:@"Mac Drive Cleaner" font:[NSFont boldSystemFontOfSize:28]];
    NSTextField *subtitleLabel = [self labelWithString:@"Scan temp files and oversized files, then send them to Trash instead of deleting permanently." font:[NSFont systemFontOfSize:13 weight:NSFontWeightRegular]];
    subtitleLabel.textColor = NSColor.secondaryLabelColor;

    self.tempSummaryLabel = [self summaryLabel];
    self.largeSummaryLabel = [self summaryLabel];
    self.selectedSummaryLabel = [self summaryLabel];

    NSStackView *summaryStack = [[NSStackView alloc] init];
    summaryStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    summaryStack.spacing = 12;
    summaryStack.distribution = NSStackViewDistributionFillEqually;
    [summaryStack addArrangedSubview:[self summaryCardWithTitle:@"Temporary Files" output:self.tempSummaryLabel]];
    [summaryStack addArrangedSubview:[self summaryCardWithTitle:@"Large Files" output:self.largeSummaryLabel]];
    [summaryStack addArrangedSubview:[self summaryCardWithTitle:@"Selected" output:self.selectedSummaryLabel]];

    self.searchField = [[NSSearchField alloc] init];
    self.searchField.placeholderString = @"Search by file name or path";
    self.searchField.delegate = self;
    self.searchField.target = self;
    self.searchField.action = @selector(filtersChanged:);

    self.tempToggle = [self checkboxWithTitle:@"Temp Files" state:NSControlStateValueOn action:@selector(filtersChanged:)];
    self.largeToggle = [self checkboxWithTitle:@"Large Files" state:NSControlStateValueOn action:@selector(filtersChanged:)];

    self.thresholdField = [[NSTextField alloc] init];
    self.thresholdField.stringValue = @"500";
    self.thresholdField.alignment = NSTextAlignmentRight;
    self.thresholdField.delegate = self;
    self.thresholdField.target = self;
    self.thresholdField.action = @selector(filtersChanged:);

    NSTextField *thresholdSuffix = [self labelWithString:@"MB minimum for large-file scan" font:[NSFont systemFontOfSize:12]];

    NSButton *scanButton = [self actionButtonWithTitle:@"Scan Again" action:@selector(rescan:)];
    NSButton *selectAllButton = [self actionButtonWithTitle:@"Select All Visible" action:@selector(selectAllVisible:)];
    NSButton *clearSelectionButton = [self actionButtonWithTitle:@"Clear Selection" action:@selector(clearSelection:)];
    NSButton *trashSelectedButton = [self actionButtonWithTitle:@"Move Selected to Trash" action:@selector(moveSelectedToTrash:)];
    NSButton *trashVisibleButton = [self actionButtonWithTitle:@"Move All Visible to Trash" action:@selector(moveVisibleToTrash:)];
    trashVisibleButton.bezelColor = NSColor.systemRedColor;

    NSStackView *filterRow = [[NSStackView alloc] init];
    filterRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    filterRow.spacing = 10;
    filterRow.alignment = NSLayoutAttributeCenterY;
    [filterRow addArrangedSubview:self.searchField];
    [filterRow addArrangedSubview:self.tempToggle];
    [filterRow addArrangedSubview:self.largeToggle];
    [filterRow addArrangedSubview:[self spacer]];
    [filterRow addArrangedSubview:self.thresholdField];
    [filterRow addArrangedSubview:thresholdSuffix];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.controlSize = NSControlSizeLarge;
    [self.searchField.widthAnchor constraintGreaterThanOrEqualToConstant:280].active = YES;
    self.thresholdField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.thresholdField.widthAnchor constraintEqualToConstant:70].active = YES;

    NSStackView *actionRow = [[NSStackView alloc] init];
    actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actionRow.spacing = 10;
    [actionRow addArrangedSubview:scanButton];
    [actionRow addArrangedSubview:selectAllButton];
    [actionRow addArrangedSubview:clearSelectionButton];
    [actionRow addArrangedSubview:[self spacer]];
    [actionRow addArrangedSubview:trashSelectedButton];
    [actionRow addArrangedSubview:trashVisibleButton];

    self.tableView = [[NSTableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.usesAlternatingRowBackgroundColors = NO;
    self.tableView.headerView = [[NSTableHeaderView alloc] init];
    self.tableView.rowHeight = 30;
    self.tableView.intercellSpacing = NSMakeSize(8, 6);
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;

    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCSelectionColumn title:@"Mark" width:56]];
    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCNameColumn title:@"Name" width:220]];
    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCReasonColumn title:@"Type" width:90]];
    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCSizeColumn title:@"Size" width:110]];
    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCModifiedColumn title:@"Modified" width:170]];
    [self.tableView addTableColumn:[self tableColumnWithIdentifier:MDCPathColumn title:@"Location" width:500]];

    NSScrollView *tableScrollView = [[NSScrollView alloc] init];
    tableScrollView.hasVerticalScroller = YES;
    tableScrollView.borderType = NSBezelBorder;
    tableScrollView.documentView = self.tableView;

    self.statusLabel = [self labelWithString:@"Ready to scan." font:[NSFont systemFontOfSize:12]];

    self.warningsView = [[NSTextView alloc] init];
    self.warningsView.editable = NO;
    self.warningsView.selectable = YES;
    self.warningsView.drawsBackground = NO;
    self.warningsView.font = [NSFont systemFontOfSize:11];

    NSScrollView *warningsScrollView = [[NSScrollView alloc] init];
    warningsScrollView.hasVerticalScroller = YES;
    warningsScrollView.borderType = NSBezelBorder;
    warningsScrollView.documentView = self.warningsView;
    warningsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [warningsScrollView.heightAnchor constraintEqualToConstant:96].active = YES;

    NSStackView *rootStack = [[NSStackView alloc] init];
    rootStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    rootStack.spacing = 14;
    rootStack.edgeInsets = NSEdgeInsetsMake(18, 18, 18, 18);
    rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [rootStack addArrangedSubview:titleLabel];
    [rootStack addArrangedSubview:subtitleLabel];
    [rootStack addArrangedSubview:summaryStack];
    [rootStack addArrangedSubview:filterRow];
    [rootStack addArrangedSubview:actionRow];
    [rootStack addArrangedSubview:tableScrollView];
    [rootStack addArrangedSubview:self.statusLabel];
    [rootStack addArrangedSubview:warningsScrollView];

    [contentView addSubview:rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [rootStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [rootStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [rootStack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [rootStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
    ]];

    [self.window makeKeyAndOrderFront:nil];
}

- (void)buildMainMenu {
    NSString *appName = @"Mac Drive Cleaner";

    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", appName]
                                                       action:@selector(orderFrontStandardAboutPanel:)
                                                keyEquivalent:@""];
    aboutItem.target = NSApp;
    [appMenu addItem:aboutItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hideItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Hide %@", appName]
                                                      action:@selector(hide:)
                                               keyEquivalent:@"h"];
    hideItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    hideItem.target = NSApp;
    [appMenu addItem:hideItem];

    NSMenuItem *hideOthersItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                            action:@selector(hideOtherApplications:)
                                                     keyEquivalent:@"h"];
    hideOthersItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    hideOthersItem.target = NSApp;
    [appMenu addItem:hideOthersItem];

    NSMenuItem *showAllItem = [[NSMenuItem alloc] initWithTitle:@"Show All"
                                                         action:@selector(unhideAllApplications:)
                                                  keyEquivalent:@""];
    showAllItem.target = NSApp;
    [appMenu addItem:showAllItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    quitItem.target = NSApp;
    [appMenu addItem:quitItem];

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    [windowMenuItem setSubmenu:windowMenu];

    [NSApp setMainMenu:mainMenu];
    [NSApp setWindowsMenu:windowMenu];
}

- (NSTextField *)labelWithString:(NSString *)string font:(NSFont *)font {
    NSTextField *label = [[NSTextField alloc] init];
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    label.stringValue = string ?: @"";
    label.font = font;
    return label;
}

- (NSTextField *)summaryLabel {
    NSTextField *label = [self labelWithString:@"0 files • 0 KB" font:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightSemibold]];
    return label;
}

- (NSView *)summaryCardWithTitle:(NSString *)title output:(NSTextField *)outputLabel {
    NSBox *box = [[NSBox alloc] init];
    box.boxType = NSBoxCustom;
    box.cornerRadius = 12.0;
    box.borderWidth = 1.0;
    box.borderColor = NSColor.separatorColor;
    box.fillColor = [NSColor controlBackgroundColor];
    box.contentViewMargins = NSSizeFromCGSize(CGSizeMake(14, 12));

    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 8;
    [stack addArrangedSubview:[self labelWithString:title font:[NSFont boldSystemFontOfSize:13]]];
    [stack addArrangedSubview:outputLabel];
    box.contentView = stack;
    return box;
}

- (NSButton *)checkboxWithTitle:(NSString *)title state:(NSControlStateValue)state action:(SEL)action {
    NSButton *button = [[NSButton alloc] init];
    button.buttonType = NSButtonTypeSwitch;
    button.title = title;
    button.state = state;
    button.target = self;
    button.action = action;
    return button;
}

- (NSButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (NSView *)spacer {
    NSView *view = [[NSView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view.widthAnchor constraintGreaterThanOrEqualToConstant:10].active = YES;
    return view;
}

- (NSTableColumn *)tableColumnWithIdentifier:(NSString *)identifier title:(NSString *)title width:(CGFloat)width {
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
    column.title = title;
    column.width = width;
    column.minWidth = width;
    if ([identifier isEqualToString:MDCPathColumn]) {
        column.resizingMask = NSTableColumnAutoresizingMask;
    } else {
        column.resizingMask = NSTableColumnNoResizing;
    }
    return column;
}

- (MDCReason)activeReasons {
    MDCReason reasons = 0;
    if (self.tempToggle.state == NSControlStateValueOn) {
        reasons |= MDCReasonTemporary;
    }
    if (self.largeToggle.state == NSControlStateValueOn) {
        reasons |= MDCReasonLarge;
    }
    return reasons;
}

- (NSArray<NSURL *> *)temporaryRoots {
    NSString *tempPath = NSTemporaryDirectory();
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath isDirectory:YES];
    NSURL *cacheURL = [NSFileManager.defaultManager.homeDirectoryForCurrentUser URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES];
    return @[tempURL, cacheURL];
}

- (NSArray<NSURL *> *)largeScanRoots {
    return @[NSFileManager.defaultManager.homeDirectoryForCurrentUser];
}

- (NSArray<NSURL *> *)excludedLargeRoots {
    NSURL *home = NSFileManager.defaultManager.homeDirectoryForCurrentUser;
    return @[
        [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES].standardizedURL,
        [[home URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES] standardizedURL],
        [[home URLByAppendingPathComponent:@".Trash" isDirectory:YES] standardizedURL]
    ];
}

- (unsigned long long)thresholdBytes {
    NSInteger megabytes = MAX(self.thresholdField.integerValue, 1);
    return (unsigned long long)megabytes * 1024ULL * 1024ULL;
}

- (IBAction)rescan:(id)sender {
    (void)sender;
    if (self.isScanning || self.isTrashing) {
        return;
    }

    self.isScanning = YES;
    [self updateStatus:@"Scanning temp files and large files in your home folder..."];
    [self.warnings removeAllObjects];
    [self refreshWarnings];

    NSArray<NSURL *> *tempRoots = [self temporaryRoots];
    NSArray<NSURL *> *largeRoots = [self largeScanRoots];
    NSArray<NSURL *> *excludedLargeRoots = [self excludedLargeRoots];
    unsigned long long threshold = [self thresholdBytes];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableDictionary<NSString *, MDCFileItem *> *itemsByPath = [[NSMutableDictionary alloc] init];
        NSMutableArray<NSString *> *warnings = [[NSMutableArray alloc] init];

        for (NSURL *root in tempRoots) {
            [self collectFilesFromRoot:root
                             rootLabel:([root.path containsString:@"Caches"] ? @"User Cache Files" : @"System Temporary Files")
                               reasons:MDCReasonTemporary
                         minimumSizeMB:0
                         excludedRoots:@[]
                       includeHidden:YES
                           outputMap:itemsByPath
                             warnings:warnings];
        }

        for (NSURL *root in largeRoots) {
            [self collectFilesFromRoot:root
                             rootLabel:@"Home Folder Scan"
                               reasons:MDCReasonLarge
                         minimumSizeMB:threshold
                         excludedRoots:excludedLargeRoots
                       includeHidden:NO
                           outputMap:itemsByPath
                             warnings:warnings];
        }

        NSArray<MDCFileItem *> *sorted = [itemsByPath.allValues sortedArrayUsingComparator:^NSComparisonResult(MDCFileItem *lhs, MDCFileItem *rhs) {
            if (lhs.sizeInBytes > rhs.sizeInBytes) {
                return NSOrderedAscending;
            }
            if (lhs.sizeInBytes < rhs.sizeInBytes) {
                return NSOrderedDescending;
            }
            return [lhs.url.lastPathComponent localizedCaseInsensitiveCompare:rhs.url.lastPathComponent];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.isScanning = NO;
            self.allItems = [sorted mutableCopy];
            self.warnings = warnings;
            [self rebuildVisibleItems];
            if (sorted.count == 0) {
                [self updateStatus:@"No temp files or large files matched the current scan settings."];
            } else {
                unsigned long long totalBytes = 0;
                for (MDCFileItem *item in sorted) {
                    totalBytes += item.sizeInBytes;
                }
                [self updateStatus:[NSString stringWithFormat:@"Found %lu item(s) using %@.", (unsigned long)sorted.count, MDCFormatBytes(totalBytes)]];
            }
        });
    });
}

- (void)collectFilesFromRoot:(NSURL *)root
                   rootLabel:(NSString *)rootLabel
                     reasons:(MDCReason)reasons
               minimumSizeMB:(unsigned long long)minimumSize
               excludedRoots:(NSArray<NSURL *> *)excludedRoots
                 includeHidden:(BOOL)includeHidden
                   outputMap:(NSMutableDictionary<NSString *, MDCFileItem *> *)outputMap
                     warnings:(NSMutableArray<NSString *> *)warnings {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:root.path isDirectory:&isDirectory] || !isDirectory) {
        return;
    }

    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsPackageDescendants;
    if (!includeHidden) {
        options |= NSDirectoryEnumerationSkipsHiddenFiles;
    }

    NSArray<NSURLResourceKey> *keys = @[
        NSURLIsDirectoryKey,
        NSURLIsRegularFileKey,
        NSURLIsSymbolicLinkKey,
        NSURLFileSizeKey,
        NSURLTotalFileAllocatedSizeKey,
        NSURLContentModificationDateKey
    ];

    NSDirectoryEnumerator<NSURL *> *enumerator = [fileManager enumeratorAtURL:root
                                                   includingPropertiesForKeys:keys
                                                                      options:options
                                                                 errorHandler:^BOOL(NSURL * _Nonnull url, NSError * _Nonnull error) {
        if (![self shouldSilenceEnumerationError:error forURL:url scanReason:reasons]) {
            [warnings addObject:[NSString stringWithFormat:@"Could not inspect %@: %@", url.path, error.localizedDescription]];
        }
        return YES;
    }];

    for (NSURL *candidate in enumerator) {
        NSURL *standardized = candidate.standardizedURL;
        if ([self shouldSkipURL:standardized excludedRoots:excludedRoots scanReason:reasons]) {
            [enumerator skipDescendants];
            continue;
        }

        NSError *resourceError = nil;
        NSDictionary<NSURLResourceKey, id> *values = [standardized resourceValuesForKeys:keys error:&resourceError];
        if (resourceError != nil || values == nil) {
            continue;
        }

        if ([values[NSURLIsSymbolicLinkKey] boolValue]) {
            [enumerator skipDescendants];
            continue;
        }
        if ([values[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
        if (![values[NSURLIsRegularFileKey] boolValue]) {
            continue;
        }

        NSNumber *sizeNumber = values[NSURLTotalFileAllocatedSizeKey] ?: values[NSURLFileSizeKey];
        unsigned long long size = sizeNumber.unsignedLongLongValue;
        if (minimumSize > 0 && size < minimumSize) {
            continue;
        }

        NSString *key = standardized.path;
        MDCFileItem *existing = outputMap[key];
        NSDate *modifiedDate = values[NSURLContentModificationDateKey];
        if (existing != nil) {
            [existing mergeReason:reasons sizeInBytes:size modifiedDate:modifiedDate rootLabel:rootLabel];
        } else {
            outputMap[key] = [[MDCFileItem alloc] initWithURL:standardized
                                                      reasons:reasons
                                                  sizeInBytes:size
                                                 modifiedDate:modifiedDate
                                                    rootLabel:rootLabel];
        }
    }
}

- (BOOL)shouldSkipURL:(NSURL *)url excludedRoots:(NSArray<NSURL *> *)excludedRoots scanReason:(MDCReason)scanReason {
    NSString *path = url.path;
    for (NSURL *excludedRoot in excludedRoots) {
        NSString *excludedPath = excludedRoot.path;
        if ([path isEqualToString:excludedPath] || [path hasPrefix:[excludedPath stringByAppendingString:@"/"]]) {
            return YES;
        }
    }

    if ((scanReason & MDCReasonTemporary) != 0) {
        NSString *lastPathComponent = url.lastPathComponent ?: @"";
        if ([lastPathComponent isEqualToString:@"TemporaryItems"]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)shouldSilenceEnumerationError:(NSError *)error forURL:(NSURL *)url scanReason:(MDCReason)scanReason {
    if (error == nil) {
        return NO;
    }

    if ((scanReason & MDCReasonTemporary) == 0) {
        return NO;
    }

    NSString *path = url.path ?: @"";
    NSString *lastPathComponent = url.lastPathComponent ?: @"";
    BOOL isPermissionDenied = NO;

    if ([error.domain isEqualToString:NSCocoaErrorDomain]) {
        isPermissionDenied = (error.code == NSFileReadNoPermissionError);
    } else if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        isPermissionDenied = (error.code == EACCES || error.code == EPERM);
    }

    if (isPermissionDenied) {
        if ([lastPathComponent isEqualToString:@"TemporaryItems"]) {
            return YES;
        }
        if ([path containsString:@"/T/com.apple."]) {
            return YES;
        }
    }

    return NO;
}

- (IBAction)filtersChanged:(id)sender {
    (void)sender;
    [self rebuildVisibleItems];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    (void)obj;
    [self rebuildVisibleItems];
}

- (void)rebuildVisibleItems {
    MDCReason reasons = [self activeReasons];
    NSString *query = self.searchField.stringValue ?: @"";

    [self.visibleItems removeAllObjects];
    for (MDCFileItem *item in self.allItems) {
        if ([item matchesQuery:query allowedReasons:reasons]) {
            [self.visibleItems addObject:item];
        }
    }

    [self.tableView reloadData];
    [self updateSummaries];
    [self refreshWarnings];
}

- (void)updateSummaries {
    NSUInteger tempCount = 0;
    unsigned long long tempBytes = 0;
    NSUInteger largeCount = 0;
    unsigned long long largeBytes = 0;
    NSUInteger selectedCount = 0;
    unsigned long long selectedBytes = 0;

    for (MDCFileItem *item in self.allItems) {
        if ((item.reasons & MDCReasonTemporary) != 0) {
            tempCount += 1;
            tempBytes += item.sizeInBytes;
        }
        if ((item.reasons & MDCReasonLarge) != 0) {
            largeCount += 1;
            largeBytes += item.sizeInBytes;
        }
        if (item.selected) {
            selectedCount += 1;
            selectedBytes += item.sizeInBytes;
        }
    }

    self.tempSummaryLabel.stringValue = [NSString stringWithFormat:@"%lu files • %@", (unsigned long)tempCount, MDCFormatBytes(tempBytes)];
    self.largeSummaryLabel.stringValue = [NSString stringWithFormat:@"%lu files • %@", (unsigned long)largeCount, MDCFormatBytes(largeBytes)];
    self.selectedSummaryLabel.stringValue = [NSString stringWithFormat:@"%lu files • %@", (unsigned long)selectedCount, MDCFormatBytes(selectedBytes)];
}

- (void)refreshWarnings {
    if (self.warnings.count == 0) {
        self.warningsView.string = @"No warnings.";
        return;
    }
    self.warningsView.string = [[self.warnings subarrayWithRange:NSMakeRange(0, MIN(self.warnings.count, 12))] componentsJoinedByString:@"\n"];
}

- (void)updateStatus:(NSString *)status {
    self.statusLabel.stringValue = status ?: @"";
}

- (IBAction)selectAllVisible:(id)sender {
    (void)sender;
    for (MDCFileItem *item in self.visibleItems) {
        item.selected = YES;
    }
    [self.tableView reloadData];
    [self updateSummaries];
}

- (IBAction)clearSelection:(id)sender {
    (void)sender;
    for (MDCFileItem *item in self.allItems) {
        item.selected = NO;
    }
    [self.tableView reloadData];
    [self updateSummaries];
}

- (NSArray<MDCFileItem *> *)selectedItems {
    NSMutableArray<MDCFileItem *> *selected = [[NSMutableArray alloc] init];
    for (MDCFileItem *item in self.allItems) {
        if (item.selected) {
            [selected addObject:item];
        }
    }
    return selected;
}

- (IBAction)moveSelectedToTrash:(id)sender {
    (void)sender;
    [self moveItemsToTrash:[self selectedItems]];
}

- (IBAction)moveVisibleToTrash:(id)sender {
    (void)sender;
    [self moveItemsToTrash:self.visibleItems.copy];
}

- (void)moveItemsToTrash:(NSArray<MDCFileItem *> *)items {
    if (items.count == 0 || self.isScanning || self.isTrashing) {
        return;
    }

    self.isTrashing = YES;
    [self updateStatus:[NSString stringWithFormat:@"Moving %lu item(s) to Trash...", (unsigned long)items.count]];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableSet<NSString *> *movedPaths = [[NSMutableSet alloc] init];
        NSMutableArray<NSString *> *errors = [[NSMutableArray alloc] init];

        for (MDCFileItem *item in items) {
            NSError *trashError = nil;
            [fileManager trashItemAtURL:item.url resultingItemURL:nil error:&trashError];
            if (trashError == nil || trashError.code == NSFileNoSuchFileError) {
                [movedPaths addObject:item.url.path];
            } else {
                [errors addObject:[NSString stringWithFormat:@"%@: %@", item.url.path, trashError.localizedDescription]];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.isTrashing = NO;

            NSIndexSet *indexes = [self.allItems indexesOfObjectsPassingTest:^BOOL(MDCFileItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                (void)idx;
                (void)stop;
                return [movedPaths containsObject:obj.url.path];
            }];
            [self.allItems removeObjectsAtIndexes:indexes];
            [self.warnings removeAllObjects];
            [self.warnings addObjectsFromArray:errors];
            [self rebuildVisibleItems];

            if (errors.count == 0) {
                [self updateStatus:[NSString stringWithFormat:@"Moved %lu item(s) to Trash.", (unsigned long)movedPaths.count]];
            } else {
                [self updateStatus:[NSString stringWithFormat:@"Moved %lu item(s) to Trash. %lu item(s) could not be moved.", (unsigned long)movedPaths.count, (unsigned long)errors.count]];
            }
        });
    });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return self.visibleItems.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableView;
    MDCFileItem *item = self.visibleItems[(NSUInteger)row];
    NSString *identifier = tableColumn.identifier;

    if ([identifier isEqualToString:MDCSelectionColumn]) {
        NSButton *checkbox = [[NSButton alloc] init];
        checkbox.buttonType = NSButtonTypeSwitch;
        checkbox.title = @"";
        checkbox.state = item.selected ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.tag = row;
        checkbox.target = self;
        checkbox.action = @selector(toggleItemSelection:);
        return checkbox;
    }

    NSTextField *label = [self labelWithString:@"" font:[NSFont systemFontOfSize:12]];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;

    if ([identifier isEqualToString:MDCNameColumn]) {
        label.stringValue = item.url.lastPathComponent ?: item.url.path;
    } else if ([identifier isEqualToString:MDCReasonColumn]) {
        label.stringValue = [item reasonSummary];
    } else if ([identifier isEqualToString:MDCSizeColumn]) {
        label.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        label.stringValue = MDCFormatBytes(item.sizeInBytes);
    } else if ([identifier isEqualToString:MDCModifiedColumn]) {
        label.stringValue = MDCFormatDate(item.modifiedDate);
    } else if ([identifier isEqualToString:MDCPathColumn]) {
        label.stringValue = item.url.path;
    }

    return label;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
}

- (IBAction)toggleItemSelection:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.visibleItems.count) {
        return;
    }
    MDCFileItem *item = self.visibleItems[(NSUInteger)row];
    item.selected = (sender.state == NSControlStateValueOn);
    [self updateSummaries];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        MDCAppDelegate *delegate = [[MDCAppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
        if (iconPath.length > 0) {
            NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:iconPath];
            if (iconImage != nil) {
                [app setApplicationIconImage:iconImage];
            }
        }
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
