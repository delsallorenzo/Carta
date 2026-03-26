// Import necessary modules
import Cocoa

// FONT SELECTION
typedef NS_ENUM(NSInteger, FontType) {
    FontTypeMenlo,
    FontTypeHelvetica,
    FontTypeTimesNewRoman,
};

// Implement font selection functionality
- (void)selectFont:(FontType)fontType {
    switch (fontType) {
        case FontTypeMenlo:
            // Set Menlo font
            break;
        case FontTypeHelvetica:
            // Set Helvetica font
            break;
        case FontTypeTimesNewRoman:
            // Set Times New Roman font
            break;
    }
}

// PASTE FROM CLIPBOARD
- (void)pasteFromClipboard {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *copiedString = [pasteboard stringForType:NSPasteboardTypeString];
    // Handle the pasted string
}

// MENU BAR ONLY MODE
- (void)setupAccessoryActivationPolicy {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

// RESOURCE OPTIMIZATION
- (void)optimizeResources {
    // Implement resource optimization here
}