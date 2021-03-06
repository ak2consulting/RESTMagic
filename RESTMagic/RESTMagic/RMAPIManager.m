//
//  RMAPIManager.m
//  RESTMagic
//


#import "RMAPIManager.h"
#import "SynthesizeSingleton.h"

@implementation RMAPIManager
SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_CUSTOM_METHOD(RMAPIManager, sharedAPIManager)

- (id)init
{
  self = [super init];
  NSString *filePath = [[NSBundle mainBundle] pathForResource:@"RESTMagic" ofType:@"plist"];
  _settings = [[NSDictionary alloc] initWithContentsOfFile:filePath];
  if (_settings[@"BaseURL"]) {
    _baseURL = [NSURL URLWithString:_settings[@"BaseURL"]];
  }
  return self;
}

- (NSString *)nameForResourceAtPath:(NSString *)path
{
  if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
    path = [self apiPathFromFullPath:path];
  }
  return [path componentsSeparatedByString:@"/"][0];
}

- (NSString *)nameForResourceAtURL:(NSURL *)url
{
  return [[[[url path] componentsSeparatedByString:@"/"] lastObject] stringByReplacingOccurrencesOfString:@".json" withString:@""];
}

- (NSURL *)URLForResourceAtPath:(NSString *)path
{
  return [NSURL URLWithString:path relativeToURL:_baseURL];
}


- (NSString *)urlForResourceAtPath:(NSString *)path
{
  return [[self URLForResourceAtPath:path] absoluteString];
}

- (NSString *)templateUrlForResourceAtUrl:(NSURL *)url
{
  //check for parts of the path that are actually unique identifiers

  NSString *lastPartOfPath = [[url pathComponents] lastObject];
  NSString *potentialId = [lastPartOfPath componentsSeparatedByString:@"."][0];

  if ([potentialId intValue] || [potentialId isEqualToString:@"0"]) {
    NSMutableArray *restOfPath = [NSMutableArray arrayWithArray:[[url path]componentsSeparatedByString:@"/"]];
    [restOfPath removeLastObject];

    NSString *pathBeforeId = [restOfPath componentsJoinedByString:@"/"];
    NSString *pathAfterId = [[lastPartOfPath componentsSeparatedByString:@"."] lastObject];
    //TODO: make this error checking nicer
    if ([lastPartOfPath isEqualToString:pathAfterId]) {
      return [NSString stringWithFormat:@"%@%@/id", [url host], pathBeforeId];
    } else {
      return [NSString stringWithFormat:@"%@%@/id.%@", [url host], pathBeforeId, pathAfterId];
    }
  }

  return [NSString stringWithFormat:@"%@%@", [url host], [url path]];
}


- (NSString *) potentialViewControllerNameForResourceNamed:(NSString *)resourceName
{
  return [NSString stringWithFormat:@"%@%@ViewController",_settings[@"ProjectClassPrefix"],resourceName];
}

- (NSString*) apiPathFromFullPath:(NSString *)fullPath {
  NSURL* fullURL = [NSURL URLWithString:fullPath relativeToURL:_baseURL];
  NSString* path = [[[fullURL absoluteString] lowercaseString] stringByReplacingOccurrencesOfString:[[_baseURL absoluteString] lowercaseString]
                                                                                         withString:@""];
  return path;
}


- (NSString *) resourceNameForResourceAtPath:(NSString *)path
{
  NSString* resourceName = [self nameForResourceAtPath:[self apiPathFromFullPath:path]];
  return [resourceName stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                               withString:[[resourceName substringToIndex:1] uppercaseString]];
}


- (RMAuthViewController *)authViewControllerForResourceAtPath:(NSString *)path withPreviousViewController:(UIViewController*)previousController{
  NSString* potentialViewControllerName = [self potentialViewControllerNameForResourceNamed:[self resourceNameForResourceAtPath:path]];
  id viewController = [[NSClassFromString(potentialViewControllerName) alloc]
                       initWithResourceAtUrl:[self urlForResourceAtPath:path]
                       withTitle:[self nameForResourceAtPath:path]
                       withPreviousViewController:previousController];
  NSLog(@"RMAPIManager: trying auth view controller: %@",potentialViewControllerName);

  if (viewController) {
    return viewController;
  }

  potentialViewControllerName = [NSString stringWithFormat:@"%@RestMagicAuthViewController",
                                 _settings[@"ProjectClassPrefix"]];
  id rmViewController = [[NSClassFromString(potentialViewControllerName) alloc]
                         initWithResourceAtUrl:[self urlForResourceAtPath:path]
                         withTitle:[self nameForResourceAtPath:path]
                         withPreviousViewController:previousController];

  if (rmViewController) {
    NSLog(@"RMAPIManager: found custom RMAuthViewController subclass");
    return rmViewController;
  }


  return [[RMAuthViewController alloc]
          initWithResourceAtUrl:[self urlForResourceAtPath:path]
          withTitle:[self nameForResourceAtPath:path]
          withPreviousViewController:previousController];
}



- (RMViewController *)viewControllerForResourceAtPath:(NSString *)path withClassNamed:(NSString*)className{

  id rmViewController = [[NSClassFromString(className) alloc]
                         initWithResourceAtUrl:[self urlForResourceAtPath:path]
                         withTitle:[self nameForResourceAtPath:path]];
  if (rmViewController) {
    NSLog(@"RMAPIManager: found custom RMViewController subclass called: %@", className);
    return rmViewController;
  }
  else {
    return [self viewControllerForResourceAtPath:path];
  }
}


- (RMViewController *)viewControllerForResourceAtPath:(NSString *)path
{

  id viewController = [[NSClassFromString([self potentialViewControllerNameForResourceNamed:[self resourceNameForResourceAtPath:path]]) alloc] initWithResourceAtUrl:[self urlForResourceAtPath:path] withTitle:[self nameForResourceAtPath:path]];
  NSLog(@"RMAPIManager: trying view controller: %@",[self potentialViewControllerNameForResourceNamed:[self resourceNameForResourceAtPath:path]]);

  if (viewController) {
    return viewController;
  }

  id rmViewController = [[NSClassFromString([NSString stringWithFormat:@"%@RestMagicViewController",_settings[@"ProjectClassPrefix"]]) alloc] initWithResourceAtUrl:[self urlForResourceAtPath:path] withTitle:[self nameForResourceAtPath:path]];
  if (rmViewController) {
    NSLog(@"RMAPIManager: found custom RMViewController subclass");
    return rmViewController;
  }


  return [[RMViewController alloc] initWithResourceAtUrl:[self urlForResourceAtPath:path] withTitle:[self nameForResourceAtPath:path]];
}

- (RMViewController *)viewControllerForResourceAtURL:(NSURL *)url
{
  return [self viewControllerForResourceAtPath:[url absoluteString]];
}


- (BOOL)canOpenURL:(NSURL *)url {
  if ([[url host] isEqualToString:[_baseURL host]])
  {
    return YES;
  } else if (_settings[@"allowedHosts"])  {
    for (NSString* host in _settings[@"allowedHosts"]) {
      if ([[[url host] lowercaseString] isEqualToString:[host lowercaseString]]) {
        return YES;
      }
    }
  }

  return NO;

}

- (void)openURL:(NSURL *)URL withNavigationController:(UINavigationController*) navigationController shouldFlushAllViews:(BOOL)shouldFlushAllViews{
  // look for native controller
  // make a new view controller
  // pass it to a navigation controller?

  if ([self canOpenURL:URL]) {
    RMViewController *aViewController = [self viewControllerForResourceAtURL:URL];
    if (shouldFlushAllViews) {
      [navigationController setViewControllers:@[aViewController]];
    } else {
      [navigationController pushViewController:aViewController animated:YES];
    }
  } else {
    [[UIApplication sharedApplication] openURL:URL];
  }

}


- (void)openURL:(NSURL *)URL withNavigationController:(UINavigationController*) navigationController{
  [self
   openURL:URL
   withNavigationController:navigationController
   shouldFlushAllViews:NO];
}

- (void)showErrorHtml:(NSString*)html withNavController:(UINavigationController*)navigationController {
  [navigationController pushViewController:[[RMViewController alloc] initWithHtmlString:html]
                                  animated:YES];
}

- (void)handleError:(NSError*)error fromViewController:(UIViewController*)viewController{
  if ([viewController respondsToSelector:@selector(showError:)]) {
    [(id)viewController showError:error];
  }
}

- (NSURLCacheStoragePolicy)cachePolicy{
  if (_settings[@"cachePolicy"]) {
    return [_settings[@"cachePolicy"] intValue];
  } else {
    return NSURLRequestUseProtocolCachePolicy;
  }
}


@end