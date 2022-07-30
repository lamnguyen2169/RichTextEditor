//
//  EditHyperLinkToolbar.m
//  macOSRTESample
//
//  Created by lam1611 on 7/5/22.
//  Copyright © 2022 Pikle Productions. All rights reserved.
//

#import "EditHyperLinkToolbar.h"

#import "NSString+Extensions.h"

@interface EditHyperLinkToolbar () <NSTextFieldDelegate>

@property (weak) IBOutlet NSView *containerView;
@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSButton *applyButton;

@end

@implementation EditHyperLinkToolbar

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configUI];
}

// MARK: -

- (void)configUI {
    [self.containerView setWantsLayer:YES];
    [[self.containerView layer] setBackgroundColor:[[NSColor whiteColor] CGColor]];
    [[self.containerView layer] setCornerRadius:8];
}

- (void)applyFormatLink {
    NSString *urlString = [[self.textField stringValue] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [urlString validateURL:^(bool isValid) {
        if (isValid && (url != nil)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate toolbarDidChangeFormatLink:url];
            });
        } else {
            [self.delegate toolbarDidChangeFormatLink:nil];
        }
    }];
}

// MARK: - Actions

- (IBAction)toggleHyperLink:(id)sender {
    [self applyFormatLink];
}

// MARK: - NSTextFieldDelegate

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
}

- (void)controlTextDidChange:(NSNotification *)obj {
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        [self applyFormatLink];
    }
    
    return NO;
}

@end
