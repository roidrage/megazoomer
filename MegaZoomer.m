//
//  MegaZoomer.m
//  megazoomer
//
//  Created by Ian Henderson on 20.09.05.
//  Copyright 2005 Ian Henderson. All rights reserved.
//

#import "MegaZoomer.h"
#import "ZoomableWindow.h"

@interface NSMenu(TopSecretMethods)

- (NSString *)_menuName;

@end

@implementation MegaZoomer

+ (NSMenu *)windowMenu
{
	NSMenu *mainMenu = [NSApp mainMenu];
    NSEnumerator *menuEnumerator = [[mainMenu itemArray] objectEnumerator];
	NSMenu *windowMenu;
    while ((windowMenu = [[menuEnumerator nextObject] submenu]) != nil) {
        // Let's hope Apple doesn't change this...
        if ([[windowMenu _menuName] isEqualToString:@"NSWindowsMenu"]) {
            return windowMenu;
        }
    }
    return windowMenu;
}

+ (NSMenuItem *)zoomMenuItem
{
	NSMenu *windowMenu = [self windowMenu];
    
    int zoomItemIndex = [windowMenu indexOfItemWithTarget:nil andAction:@selector(performZoom:)];
    NSMenuItem *zoomMenuItem = nil;
    if (zoomItemIndex >= 0) {
        [windowMenu itemAtIndex:zoomItemIndex];
    }
    if (zoomMenuItem == nil) {
        zoomMenuItem = [windowMenu itemWithTitle:@"Zoom"];
    }
    return zoomMenuItem;
}

- (void)insertMenu
{
	NSMenu *windowMenu = [[self class] windowMenu];

	NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
    [item setRepresentedObject:self]; // So I can validate it without having to check the title.
	[item setTitle:@"Mega Zoom"];
	[item setAction:@selector(megaZoom:)];
	[item setTarget:self];
	[item setKeyEquivalent:@"\n"];
	[item setKeyEquivalentModifierMask:NSCommandKeyMask];
	[windowMenu insertItem:item atIndex:[windowMenu indexOfItemWithTarget:nil andAction:@selector(performZoom:)]+1];
}

+ (BOOL)megazoomerWorksHere
{
    static NSSet *doesntWork = nil;
    if (doesntWork == nil) {
        doesntWork = [[NSSet alloc] init]; // add bundles that don't work
    }
    return ![doesntWork containsObject:[[NSBundle mainBundle] bundleIdentifier]];
}

+ (void)load
{
	static MegaZoomer *zoomer = nil;
	if (zoomer == nil) {
		zoomer = [[self alloc] init];
        if ([self megazoomerWorksHere]) {
            [zoomer insertMenu];
            [NSWindow swizzleZoomerMethods];
        }
	}
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)item
{
    return [[NSApp keyWindow] isMegaZoomable];
}

- (void)megaZoom:sender
{
    [[NSApp keyWindow] toggleMegaZoom];
}

@end
