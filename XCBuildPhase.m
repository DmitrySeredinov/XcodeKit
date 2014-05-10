//
//  XCBuildPhase.m
//  PodBuilder
//
//  Created by William Kent on 5/10/14.
//  Copyright (c) 2014 William Kent. All rights reserved.
//

#import "XCBuildPhase.h"

@implementation XCBuildPhase

- (XCBuildFile *)buildFileWithName:(NSString *)name {
    for (XCObjectIdentifier *ident in self.properties[@"files"]) {
        XCBuildFile *file = [self.registry objectOfClass:[XCBuildFile class] withIdentifier:ident];
        if ([file.fileReference.name isEqualToString:name]) return file;
    }
    
    return nil;
}

- (XCBuildFile *)buildFileWithPath:(NSString *)path {
    for (XCObjectIdentifier *ident in self.properties[@"files"]) {
        XCBuildFile *file = [self.registry objectOfClass:[XCBuildFile class] withIdentifier:ident];
        if ([file.fileReference.path isEqualToString:path]) return file;
    }
    
    return nil;
}

- (XCFileReference *)buildFileReferenceWithName:(NSString *)name {
    for (XCObjectIdentifier *ident in self.properties[@"files"]) {
        XCBuildFile *file = [self.registry objectOfClass:[XCBuildFile class] withIdentifier:ident];
        if ([file.fileReference.name isEqualToString:name]) return file.fileReference;
    }
    
    return nil;
}

- (XCFileReference *)buildFileReferenceWithPath:(NSString *)path {
    for (NSString *ident in self.properties[@"files"]) {
        XCBuildFile *file = [self.registry objectOfClass:[XCBuildFile class] withIdentifier:[[XCObjectIdentifier alloc] initWithKey:ident]];
        if ([file.fileReference.path isEqualToString:path]) return file.fileReference;
    }
    
    return nil;
}

- (NSArray *)allBuildFileReferences {
    NSMutableArray *references = [NSMutableArray array];
    
    for (NSString *key in self.properties[@"files"]) {
        XCObjectIdentifier *ident = [[XCObjectIdentifier alloc] initWithKey:key];
        XCBuildFile *buildFile = [self.registry objectOfClass:[XCBuildFile class] withIdentifier:ident];
        [references addObject:buildFile.fileReference];
    }
    
    return references;
}

- (void)addBuildFileWithReference:(XCFileReference *)reference buildSettings:(NSDictionary *)dictionary {
    if ([self buildFileWithPath:reference.path]) return;
    if ([self buildFileWithName:reference.name]) return;
    
    XCBuildFile *file = [XCBuildFile buildFileWithFileReference:reference buildSettings:dictionary inRegistry:self.registry];
    [self.registry setResourceObject:file];
    [self.properties[@"files"] addObject:file.identifier];
}

@end

#pragma mark -

@implementation XCLinkFrameworksBuildPhase

+ (XCLinkFrameworksBuildPhase *)linkFrameworksBuildPhaseInRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXFrameworksBuildPhase";
        defaultProperties[@"buildActionMask"] = @(2147483647);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    return [registry addResourceObjectOfClass:[self class] withProperties:defaultProperties];
}

@end

#pragma mark -

@implementation XCCompileSourcesBuildPhase

+ (XCCompileSourcesBuildPhase *)compileSourcesBuildPhaseInRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXSourcesBuildPhase";
        defaultProperties[@"buildActionMask"] = @(2147483647);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    return [registry addResourceObjectOfClass:[self class] withProperties:defaultProperties];
}

- (void)addBuildFileWithReference:(XCFileReference *)reference useAutomaticReferenceCounting:(BOOL)useARC buildSettings:(NSDictionary *)dictionary {
    NSMutableDictionary *settings = [dictionary mutableCopy];
    if (!useARC) {
        NSMutableArray *flags = settings[@"COMPILE_FLAGS"];
        if (flags == nil) {
            flags = [NSMutableArray array];
            settings[@"COMPILE_FLAGS"] = flags;
        }
        
        [flags addObject:@"-fno-objc-arc"];
    }
    
    [self addBuildFileWithReference:reference buildSettings:settings];
}

@end

#pragma mark -

@implementation XCCopyResourcesBuildPhase

+ (XCCopyResourcesBuildPhase *)copyResourcesBuildPhaseInRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXResourcesBuildPhase";
        defaultProperties[@"buildActionMask"] = @(2147483647);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    return [registry addResourceObjectOfClass:[self class] withProperties:defaultProperties];
}

@end

#pragma mark -

@implementation XCRunScriptBuildPhase

+ (XCRunScriptBuildPhase *)runScriptBuildPhaseWithScript:(NSString *)source inRegistry:(XCObjectRegistry *)registry {
    return [self runScriptBuildPhaseWithScript:source interpreterPath:@"/bin/sh" inRegistry:registry];
}

+ (XCRunScriptBuildPhase *)runScriptBuildPhaseWithScript:(NSString *)source interpreterPath:(NSString *)interpreter inRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXShellScriptBuildPhase";
        defaultProperties[@"buildActionMask"] = @(2147483647);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"inputPaths"] = [NSMutableArray array];
        defaultProperties[@"outputPaths"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    NSMutableDictionary *finalProperties = [defaultProperties copy];
    finalProperties[@"shellPath"] = interpreter;
    finalProperties[@"shellScript"] = source;
    
    return [registry addResourceObjectOfClass:[self class] withProperties:finalProperties];
}

- (NSString *)name {
    return self.properties[@"name"];
}

- (void)setName:(NSString *)name {
    self.properties[@"name"] = name;
}

- (BOOL)runOnlyWhenInstalling {
    NSString *val = self.properties[@"runOnlyForDeploymentPreprocessing"];
    
    // Default to NO.
    if (val == nil) {
        return NO;
    } else if ([val isEqualToString:@"1"]) {
        return YES;
    } else if ([val isEqualToString:@"0"]) {
        return NO;
    } else {
        [NSException raise:NSInternalInconsistencyException format:@"Unrecognized 'runOnlyForDeploymentPreprocessing': %@", val];
        return NO;
    }
}

- (void)setRunOnlyWhenInstalling:(BOOL)runOnlyWhenInstalling {
    self.properties[@"runOnlyForDeploymentPreprocessing"] = runOnlyWhenInstalling ? @"1" : @"0";
}

- (NSString *)scriptSource {
    return self.properties[@"shellScript"];
}

- (void)setScriptSource:(NSString *)scriptSource {
    self.properties[@"shellScript"] = scriptSource;
}

- (NSArray *)inputFiles {
    return self.properties[@"inputFiles"];
}

- (void)setInputFiles:(NSArray *)inputFiles {
    self.properties[@"inputFiles"] = inputFiles;
}

- (NSArray *)outputFiles {
    return self.properties[@"outputFiles"];
}

- (void)setOutputFiles:(NSArray *)inputFiles {
    self.properties[@"outputFiles"] = inputFiles;
}

@end

#pragma mark -

@implementation XCCopyHeadersBuildPhase

+ (XCCopyHeadersBuildPhase *)copyHeadersBuildPhaseInRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXHeadersBuildPhase";
        defaultProperties[@"buildActionMask"] = @(2147483647);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    return [registry addResourceObjectOfClass:[self class] withProperties:defaultProperties];
}

- (void)addPublicHeaderFileWithReference:(XCFileReference *)reference buildSettings:(NSDictionary *)dictionary {
    [self addBuildFileWithReference:reference buildSettings:@{ @"ATTRIBUTES": @[ @"Public" ] }];
}

- (void)addPrivateHeaderFileWithReference:(XCFileReference *)reference buildSettings:(NSDictionary *)dictionary {
    [self addBuildFileWithReference:reference buildSettings:@{ @"ATTRIBUTES": @[ @"Private" ] }];
}

@end

#pragma mark -

@implementation XCCopyFilesBuildPhase

+ (XCCopyFilesBuildPhase *)copyFilesBuildPhaseWithName:(NSString *)name destination:(XCCopyFilesDestination)destination destinationSubdirectory:(NSString *)subdir inRegistry:(XCObjectRegistry *)registry {
    XCCopyFilesBuildPhase *phase = [self copyFilesBuildPhaseWithDestination:destination destinationSubdirectory:subdir inRegistry:registry];
    phase.properties[@"name"] = name;
    return phase;
}

+ (XCCopyFilesBuildPhase *)copyFilesBuildPhaseWithDestination:(XCCopyFilesDestination)destination destinationSubdirectory:(NSString *)subdir inRegistry:(XCObjectRegistry *)registry {
    static NSMutableDictionary *defaultProperties;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultProperties = [[NSMutableDictionary alloc] init];
        defaultProperties[@"isa"] = @"PBXCopyFilesBuildPhase";
        defaultProperties[@"buildActionMask"] = @(8);
        defaultProperties[@"files"] = [NSMutableArray array];
        defaultProperties[@"runOnlyForDeploymentPostprocessing"] = @"0";
    });
    
    NSMutableDictionary *finalProperties = [defaultProperties copy];
    finalProperties[@"dstSubfolderSpec"] = @(destination);
    finalProperties[@"dstPath"] = subdir;
    
    return [registry addResourceObjectOfClass:[self class] withProperties:finalProperties];
}

- (BOOL)copyOnlyWhenInstalling {
    NSString *val = self.properties[@"runOnlyForDeploymentPostprocessing"];
    
    // Default to NO.
    if (val == nil) {
        return NO;
    } else if ([val isEqualToString:@"1"]) {
        return YES;
    } else if ([val isEqualToString:@"0"]) {
        return NO;
    } else {
        [NSException raise:NSInternalInconsistencyException format:@"Unexpected 'runOnlyForDeploymentPostprocessing' value: %@", val];
        return NO;
    }
}

- (void)setCopyOnlyWhenInstalling:(BOOL)copyOnlyWhenInstalling {
    self.properties[@"runOnlyForDeploymentPostprocessing"] = copyOnlyWhenInstalling ? @"1" : @"0";
}

- (XCCopyFilesDestination)destination {
    return (XCCopyFilesDestination) [self.properties[@"dstSubfolderSpec"] integerValue];
}

- (void)setDestination:(XCCopyFilesDestination)destination {
    self.properties[@"dstSubfolderSpec"] = @((NSInteger) destination);
}

- (NSString *)destinationSubdirectory {
    return self.properties[@"dstPath"];
}

- (void)setDestinationSubdirectory:(NSString *)destinationSubdirectory {
    self.properties[@"dstPath"] = destinationSubdirectory;
}

- (NSString *)name {
    return self.properties[@"name"];
}

- (void)setName:(NSString *)name {
    self.properties[@"name"] = name;
}

@end
