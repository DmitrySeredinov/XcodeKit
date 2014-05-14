/*
 * The sources in the "XcodeKit" directory are based on the Ruby project Xcoder.
 *
 * Copyright (c) 2012 cisimple
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "XCObjectRegistry.h"
#import "XCResource.h"
#import "XCProject.h"

static NSString *XCRepeatedString(NSString *base, NSUInteger times) {
    if (times == 0) return @"";
    
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 50;
    });
    
    NSString *cacheKey = [NSString stringWithFormat:@"%lu@%@", (unsigned long) times, base];
    NSString *cacheValue = [cache objectForKey:cacheKey];
    if (cacheValue != nil) return cacheValue;
    
    NSMutableString *repeated = [NSMutableString string];
    for (NSUInteger i = 0; i < times; i++) [repeated appendString:base];
    cacheValue = repeated;
    [cache setObject:cacheValue forKey:cacheKey];
    
    return cacheValue;
}

static NSString *XCQuoteString(NSString *original) {
    NSMutableString *retval = [original mutableCopy];
    
    [retval replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\t" withString:@"\\t" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\v" withString:@"\\v" options:0 range:NSMakeRange(0, retval.length)];
    [retval replaceOccurrencesOfString:@"\f" withString:@"\\f" options:0 range:NSMakeRange(0, retval.length)];
    
    return retval;
}

NSString * const XCInvalidProjectFileException = @"XCInvalidProjectFileException";

#pragma mark -

@implementation XCObjectRegistry

+ (XCObjectRegistry *)objectRegistryForEmptyProjectWithName:(NSString *)projectName {
    XCObjectRegistry *registry = [[[self class] alloc] init];
    
    XCGroup *mainGroup = [XCGroup createLogicalGroupWithName:projectName inRegistry:registry];
    XCProject *project = [XCProject createProjectWithMainGroup:mainGroup inRegistry:registry];
    [registry setResourceObject:mainGroup];
    [registry setResourceObject:project];
    
    registry.project = project;
    return registry;
}

+ (XCObjectRegistry *)objectRegistryWithXcodePBXProjectText:(NSString *)pbxproj {
    extern XCObjectRegistry * XCParsePBXProjectFile(NSString *pbxprojSource);
    return XCParsePBXProjectFile(pbxproj);
}

- (id)init {
    NSDictionary *initialPlist = @{ @"formatVersion": @"1", @"classes": [NSDictionary dictionary],
                                    @"objectVersion": @"46", @"objects": [NSMutableDictionary dictionary] };
    return [self initWithProjectPropertyList:initialPlist];
}

- (id)initWithProjectPropertyList:(NSDictionary *)propertyList {
    self = [super init];
    
    if (self) {
        _projectPropertyList = [propertyList mutableCopy];
    }
    
    return self;
}

#pragma mark Properties

- (NSInteger)objectVersion {
    return [self.projectPropertyList[@"objectVersion"] integerValue];
}

- (void)setObjectVersion:(NSInteger)archiveVersion {
    self.projectPropertyList[@"objectVersion"] = @(archiveVersion);
}

- (XCProject *)project {
    XCObjectIdentifier *identifier = [[XCObjectIdentifier alloc] initWithKey:self.projectPropertyList[@"rootObject"] targetDescription:@"Project object"];
    return (XCProject *) [self objectWithIdentifier:identifier];
}

- (void)setProject:(XCProject *)project {
    [self setResourceObject:project];
    self.projectPropertyList[@"rootObject"] = project.identifier;
}

- (NSMutableDictionary *)objectDictionary {
    return self.projectPropertyList[@"objects"];
}

- (XCResource *)objectWithIdentifier:(XCObjectIdentifier *)identifier {
    XCResource *resource = [[XCResource alloc] initWithIdentifier:identifier registry:self];
    if (resource.resourceDescription != nil) identifier.targetDescription = resource.resourceDescription;
    return resource;
}

- (id)objectOfClass:(Class)cls withIdentifier:(XCObjectIdentifier *)identifier {
    NSAssert([cls isKindOfClass:[XCResource class]], @"Class %@ must inherit from XCResource", NSStringFromClass(cls));
    return [[cls alloc] initWithIdentifier:identifier registry:self];
}

- (NSDictionary *)propertiesForObjectWithIdentifier:(XCObjectIdentifier *)identifier {
    return self.objectDictionary[identifier.key];
}

- (id)addResourceObjectOfClass:(Class)cls withProperties:(NSDictionary *)properties {
    NSAssert([cls isKindOfClass:[XCResource class]], @"Class %@ must inherit from XCResource", NSStringFromClass(cls));
    
    XCObjectIdentifier *identifier = [[XCObjectIdentifier alloc] initWithTargetDescription:nil existingKeys:self.objectDictionary.allKeys];
    self.objectDictionary[identifier.key] = properties;
    return [[cls alloc] initWithIdentifier:identifier registry:self];
}

- (void)setResourceObject:(XCResource *)resource {
    self.objectDictionary[resource.identifier.key] = resource.properties;
}

- (void)removeResourceObjectWithIdentifier:(XCObjectIdentifier *)identifier {
    [self.objectDictionary removeObjectForKey:identifier.key];
}

#pragma mark Removal of Unreferenced Resources

- (void)addObjectIdentifiersInDictionary:(NSDictionary *)dict toSet:(NSMutableSet *)set {
    for (id object in dict.allValues) {
        if ([object isKindOfClass:[XCObjectIdentifier class]]) [set addObject:object];
        else if ([object isKindOfClass:[NSDictionary class]]) [self addObjectIdentifiersInDictionary:object toSet:set];
        else if ([object isKindOfClass:[NSArray class]]) [self addObjectIdentifiersInArray:object toSet:set];
    }
}

- (void)addObjectIdentifiersInArray:(NSArray *)list toSet:(NSMutableSet *)set {
    for (id object in list) {
        if ([object isKindOfClass:[XCObjectIdentifier class]]) [set addObject:object];
        else if ([object isKindOfClass:[NSDictionary class]]) [self addObjectIdentifiersInDictionary:object toSet:set];
        else if ([object isKindOfClass:[NSArray class]]) [self addObjectIdentifiersInArray:object toSet:set];
    }
}

- (void)removeUnreferencedResources {
    NSMutableSet *set = [NSMutableSet set];
    [self addObjectIdentifiersInDictionary:self.objectDictionary toSet:set];
    
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSString *key in self.objectDictionary.allKeys) {
        if (![set containsObject:key]) [keysToRemove addObject:key];
    }
    
    for (NSString *key in keysToRemove) {
        [self.objectDictionary removeObjectForKey:key];
    }
}

#pragma mark PBX Project Text Generation

- (NSString *)escapedPBXProjectStringForString:(NSString *)base {
    NSUInteger length = base.length;
    NSCharacterSet *cset = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"];
    BOOL needsQuoting = NO;
    
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [base characterAtIndex:i];
        if (![cset characterIsMember:c]) {
            needsQuoting = YES;
            break;
        }
    }
    
    if (needsQuoting) return [NSString stringWithFormat:@"\"%@\"", XCQuoteString(base)];
    else return base;
}

- (void)generatePBXProjectTextForDictionary:(NSDictionary *)dict inString:(NSMutableString *)string indentLevel:(NSUInteger)tabCount {
    NSString *indent = XCRepeatedString(@"\t", tabCount);
    NSString *innerIndent = XCRepeatedString(@"\t", tabCount + 1);
    
    [string appendString:@"{\n"];
    
    for (NSString *key in dict.allKeys) {
        id value = dict[key];
        
        [string appendString:innerIndent];
        [string appendFormat:@"%@ = ", [self escapedPBXProjectStringForString:key]];
        
        if ([value isKindOfClass:[NSString class]]) {
            [string appendString:[self escapedPBXProjectStringForString:value]];
        } else if ([value isKindOfClass:[NSNumber class]]) {
            [string appendString:[self escapedPBXProjectStringForString:[value stringValue]]];
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            [self generatePBXProjectTextForDictionary:value inString:string indentLevel:tabCount + 1];
        } else if ([value isKindOfClass:[NSArray class]]) {
            [self generatePBXProjectTextForArray:value inString:string indentLevel:tabCount + 1];
        } else if ([value isKindOfClass:[XCObjectIdentifier class]]) {
            [string appendString:[value description]];
        }
        
        [string appendString:@";\n"];
    }
    
    [string appendString:indent];
    [string appendString:@"}"];
}

- (void)generatePBXProjectTextForArray:(NSArray *)array inString:(NSMutableString *)string indentLevel:(NSUInteger)tabCount {
    NSString *indent = XCRepeatedString(@"\t", tabCount);
    NSString *innerIndent = XCRepeatedString(@"\t", tabCount + 1);
    
    [string appendString:@"(\n"];
    
    for (id value in array) {
        [string appendString:innerIndent];
        if ([value isKindOfClass:[NSString class]]) {
            [string appendString:[self escapedPBXProjectStringForString:value]];
        } else if ([value isKindOfClass:[NSNumber class]]) {
            [string appendString:[self escapedPBXProjectStringForString:[value stringValue]]];
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            [self generatePBXProjectTextForDictionary:value inString:string indentLevel:tabCount + 1];
        } else if ([value isKindOfClass:[NSArray class]]) {
            [self generatePBXProjectTextForArray:value inString:string indentLevel:tabCount + 1];
        } else if ([value isKindOfClass:[XCObjectIdentifier class]]) {
            [string appendString:[value description]];
        }
        
        [string appendString:@",\n"];
    }
    
    [string appendString:indent];
    [string appendString:@")"];
}

- (NSString *)xcodePBXProjectText {
    NSMutableString *pbxproj = [NSMutableString string];
    
    [pbxproj appendString:@"// !$*UTF8*$!\n"];
    [self generatePBXProjectTextForDictionary:self.projectPropertyList inString:pbxproj indentLevel:0];
    [pbxproj appendString:@"\n"];
    
    return pbxproj;
}

@end
