part of 'init_dependencies.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  await initObjectBox();
  await initServices();
  await RustLib.init();

  // Dotenv
  await dotenv.load(fileName: '.env');

  await HomeWidget.setAppGroupId('group.com.minimallabs.vsync');

  // Block Landscape View
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ]);

  // Draw edge to edge behind both system bars for every phone. The status
  // bar becomes transparent so the app's own surface reaches the top of the
  // screen and no opaque (usually black) bar obstructs the top section, while
  // the clock and battery icons stay visible — their brightness is set from
  // the app theme via `AnnotatedRegion<SystemUiOverlayStyle>` in `main.dart`.
  // Android 15+ enforces this mode anyway; doing it explicitly keeps older
  // versions identical instead of black-barred.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Register the InterceptedClient
  serviceLocator.registerSingleton<http.Client>(Client());

  // Register SSL client that trusts the VTOP server certificate
  serviceLocator.registerSingleton<IOClient>(
    IOClient(
      HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) =>
                host == ServerConstants.vtopDomain,
    ),
  );

  // Initialize Timezone
  tzlt.initializeTimeZones();
  final kolkata = tz.getLocation('Asia/Kolkata');
  tz.setLocalLocation(kolkata);
}

Future<void> initObjectBox() async {
  final objectbox = await ObjectBox.create();
  serviceLocator.registerSingleton<Store>(objectbox.store);
}

Future<void> initServices() async {
  serviceLocator.registerSingleton<FlutterSecureStorage>(
    const FlutterSecureStorage(),
  );

  serviceLocator.registerSingleton<SecureStorageService>(
    SecureStorageService(serviceLocator<FlutterSecureStorage>()),
  );

  serviceLocator.registerSingleton<VtopClientService>(VtopClientService());

  // Hydrate the demo-mode flag so it can be read synchronously everywhere.
  await DemoService.init();

  serviceLocator.registerSingleton<ConnectionChecker>(
    ConnectionCheckerImpl(InternetConnection()),
  );
}
