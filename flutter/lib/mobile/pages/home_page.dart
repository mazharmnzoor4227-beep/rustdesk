import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:flutter_hbb/web/settings_page.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../common/widgets/chat_page.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';
import 'connection_page.dart';

abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  var _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  final List<PageShape> _pages = [];
  int _chatPageTabIndex = -1;
  bool get isChatPageCurrentTab => isAndroid
      ? _selectedIndex == _chatPageTabIndex
      : false; // change this when ios have chat page

  void refreshPages() {
    setState(() {
      initPages();
    });
  }

  // DoorDesk: jump to the Share (server) tab, e.g. from Family Help.
  void goToServerPage() {
    final idx = _pages.indexWhere((p) => p is ServerPage);
    if (idx >= 0 && idx != _selectedIndex) {
      setState(() {
        _selectedIndex = idx;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initPages();
  }

  void initPages() {
    _pages.clear();
    if (!bind.isIncomingOnly()) {
      _pages.add(ConnectionPage(
        appBarActions: [],
      ));
    }
    if (isAndroid && !bind.isOutgoingOnly()) {
      _chatPageTabIndex = _pages.length;
      _pages.addAll([ChatPage(type: ChatPageType.mobileMain), ServerPage()]);
    }
    _pages.add(SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
          } else {
            return true;
          }
          return false;
        },
        child: Scaffold(
          // backgroundColor: MyTheme.grayBg,
          appBar: AppBar(
            centerTitle: true,
            title: appTitle(),
            actions: _pages.elementAt(_selectedIndex).appBarActions,
          ),
          bottomNavigationBar: _buildBottomNav(),
          body: _pages.elementAt(_selectedIndex),
        ));
  }

  void _onNavTap(int index) {
    setState(() {
      // close chat overlay when go chat page
      if (_selectedIndex != index) {
        _selectedIndex = index;
        if (isChatPageCurrentTab) {
          gFFI.chatModel.hideChatIconOverlay();
          gFFI.chatModel.hideChatWindowOverlay();
          gFFI.chatModel
              .mobileClearClientUnread(gFFI.chatModel.currentKey.connId);
        }
      }
    });
  }

  // DoorDesk bottom navigation: dark/light surface with a sliding
  // gradient pill behind the active tab.
  Widget _buildBottomNav() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: navigationBarKey,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101215) : Colors.white,
        border: Border(
            top: BorderSide(
                color: MyTheme.accent.withOpacity(dark ? 0.18 : 0.35),
                width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _pages.length;
            return Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: tabWidth * _selectedIndex + 8,
                top: 7,
                width: tabWidth - 16,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: MyTheme.ddPrimaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: MyTheme.accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                ),
              ),
              Row(
                children: _pages.asMap().entries.map((entry) {
                  final i = entry.key;
                  final page = entry.value;
                  final selected = i == _selectedIndex;
                  final color =
                      selected ? MyTheme.ddOnAccent : MyTheme.darkGray;
                  final iconWidget = page.icon;
                  final IconData? iconData =
                      iconWidget is Icon ? iconWidget.icon : null;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _onNavTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          iconData != null
                              ? Icon(iconData, color: color, size: 24)
                              : IconTheme(
                                  data:
                                      IconThemeData(color: color, size: 24),
                                  child: iconWidget),
                          const SizedBox(height: 2),
                          Text(page.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget appTitle() {
    final currentUser = gFFI.chatModel.currentUser;
    final currentKey = gFFI.chatModel.currentKey;
    if (isChatPageCurrentTab &&
        currentUser != null &&
        currentKey.peerId.isNotEmpty) {
      final connected =
          gFFI.serverModel.clients.any((e) => e.id == currentKey.connId);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: currentKey.isOut
                ? translate('Outgoing connection')
                : translate('Incoming connection'),
            child: Icon(
              currentKey.isOut
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${currentUser.firstName}   ${currentUser.id}",
                  ),
                  if (connected)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 133, 246, 199)),
                    ).marginSymmetric(horizontal: 2),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: MyTheme.ddPrimaryGradient,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                  color: MyTheme.accent.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.monitor,
              size: 18, color: MyTheme.ddOnAccent),
        ),
        const SizedBox(width: 9),
        Text(bind.mainGetAppNameSync()),
      ],
    );
  }
}

class WebHomePage extends StatelessWidget {
  final connectionPage =
      ConnectionPage(appBarActions: <Widget>[const WebSettingsPage()]);

  @override
  Widget build(BuildContext context) {
    stateGlobal.isInMainPage = true;
    handleUnilink(context);
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text("${bind.mainGetAppNameSync()} (Preview)"),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }

  handleUnilink(BuildContext context) {
    if (webInitialLink.isEmpty) {
      return;
    }
    final link = webInitialLink;
    webInitialLink = '';
    final splitter = ["/#/", "/#", "#/", "#"];
    var fakelink = '';
    for (var s in splitter) {
      if (link.contains(s)) {
        var list = link.split(s);
        if (list.length < 2 || list[1].isEmpty) {
          return;
        }
        list.removeAt(0);
        fakelink = "rustdesk://${list.join(s)}";
        break;
      }
    }
    if (fakelink.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(fakelink);
    if (uri == null) {
      return;
    }
    final args = urlLinkToCmdArgs(uri);
    if (args == null || args.isEmpty) {
      return;
    }
    bool isFileTransfer = false;
    bool isViewCamera = false;
    bool isTerminal = false;
    String? id;
    String? password;
    var loginMethod = '';
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--connect':
        case '--play':
          id = args[i + 1];
          i++;
          break;
        case '--file-transfer':
          isFileTransfer = true;
          id = args[i + 1];
          i++;
          break;
        case '--view-camera':
          isViewCamera = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal':
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal-admin':
          setEnvTerminalAdmin();
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--password':
          password = args[i + 1];
          i++;
          break;
        case '--request-approval':
          loginMethod = 'request-approval';
          break;
        default:
          break;
      }
    }
    if (id != null) {
      connect(context, id, 
        isFileTransfer: isFileTransfer, 
        isViewCamera: isViewCamera, 
        isTerminal: isTerminal,
        loginMethod: loginMethod,
        password: password);
    }
  }
}
