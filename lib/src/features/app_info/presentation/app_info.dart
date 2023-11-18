import 'package:appimagepool/src/features/home/presentation/installed/installed_view_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:libadwaita/libadwaita.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:libadwaita_window_manager/libadwaita_window_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:simple_html_css/simple_html_css.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:appimagepool/src/utils/utils.dart';
import 'package:appimagepool/translations/translations.dart';
import 'package:path/path.dart' as p;

import '../../download/domain/download_item.dart';
import '../domain/app.dart';
import 'ap_tile.dart';
import 'custom_dialog.dart';
import 'download_button.dart';

class AppInfo extends HookConsumerWidget {
  AppInfo({Key? key, required this.app}) : super(key: key);

  final App app;
  final CarouselController _controller = CarouselController();

  @override
  Widget build(BuildContext context, ref) {
    final isLoadingDL = useState<bool>(false);
    String url = app.url != null
        ? (app.url as List).firstWhere((e) => e['type'] == 'Download',
            orElse: () => {'url': ''})['url']
        : '';
    String proUrl = app.url != null
        ? app.url!.firstWhere((e) => e['type'].toLowerCase() == 'github',
            orElse: () => {'url': ''})['url']
        : '';

    if (!proUrl.startsWith('http') && app.url != null) proUrl = github + proUrl;

    double iconSize = context.width > 500
        ? 100
        : context.width > 400
            ? 60
            : 50;
    Widget appIcon([double? size]) => app.iconUrl != null
        ? (!app.iconUrl!.endsWith('.svg'))
            ? CachedNetworkImage(
                imageUrl: app.iconUrl!,
                fit: BoxFit.cover,
                width: size,
                placeholder: (c, b) => const SizedBox(),
                errorWidget: (c, w, i) => brokenImageWidget,
              )
            : SvgPicture.network(app.iconUrl!, width: size)
        : brokenImageWidget;
    final current = useState<int>(0);
    final downloadList = ref
        .watch(installedViewStateProvider)
        .listInstalled
        .where((element) => p
            .basename(element.path)
            .toLowerCase()
            .contains(app.name!.toLowerCase()))
        .toList();

    Future<void> openApp() async {
      if (!url.contains('github.com', 0)) {
        url.launchIt();
      } else {
        if (!isLoadingDL.value) {
          isLoadingDL.value = true;
          List<String> v = url.split('github.com');
          var u = 'https://api.github.com/repos${v[1]}';
          List response;
          try {
            response = (await Dio().get(u)).data;
          } catch (e) {
            isLoadingDL.value = false;
            return;
          }
          if (response.isNotEmpty && context.mounted) {
            await showDialog(
              context: context,
              builder: (BuildContext context) => DownloadDialog(
                response,
                appIcon(50),
                (checkmap) => downloadApp(context, checkmap, ref),
              ),
            );
          } else {
            url.launchIt();
          }
          isLoadingDL.value = false;
        }
      }
    }

    return AdwScaffold(
      actions: AdwActions().windowManager,
      title: Text(app.name!),
      start: [
        AdwHeaderButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 17),
          onPressed: context.back,
        ),
      ],
      end: const [
        DownloadButton(),
      ],
      body: ListView(
        children: [
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Tooltip(
                          message: (app.url != null && proUrl.isNotEmpty)
                              ? proUrl
                              : "",
                          child: GestureDetector(
                            onTap: (app.url != null && proUrl.isNotEmpty)
                                ? proUrl.launchIt
                                : null,
                            child: SizedBox(
                                width: iconSize,
                                height: iconSize,
                                child: appIcon()),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                  app.name ??
                                      AppLocalizations.of(context)!
                                          .notAvailable,
                                  style: context.textTheme.headlineMedium),
                              SelectableText(
                                  (app.categories != null &&
                                          app.categories!.isNotEmpty
                                      ? app.categories!.join(', ')
                                      : AppLocalizations.of(context)!
                                          .notAvailable),
                                  style: context.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        const Gap(10),
                        if (downloadList.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdwButton(
                                opaque: true,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(5),
                                  bottomLeft: Radius.circular(5),
                                ),
                                backgroundColor: AdwColors.blue.backgroundColor,
                                textStyle: const TextStyle(color: Colors.white),
                                onPressed: () => ref
                                    .read(programUtilsProvider)
                                    .runProgram(
                                      location:
                                          p.dirname(downloadList.first.path),
                                      program:
                                          p.basename(downloadList.first.path),
                                    ),
                                child: const Text("Launch"),
                              ),
                              AdwButton(
                                opaque: true,
                                borderRadius: const BorderRadius.only(),
                                backgroundColor: AdwColors.blue.backgroundColor,
                                textStyle: const TextStyle(color: Colors.white),
                                onPressed: openApp,
                                child: const Icon(
                                  LucideIcons.download,
                                  size: 18,
                                ),
                              ),
                            ],
                          )
                        else if (app.url != null && url.isNotEmpty)
                          AdwButton(
                            opaque: true,
                            backgroundColor: AdwColors.blue.backgroundColor,
                            textStyle: const TextStyle(color: Colors.white),
                            onPressed: !url.contains('github.com', 0)
                                ? () => url.launchIt()
                                : !isLoadingDL.value
                                    ? () async {
                                        isLoadingDL.value = true;
                                        List<String> v =
                                            url.split('github.com');
                                        var u =
                                            'https://api.github.com/repos${v[1]}';
                                        List response;
                                        try {
                                          response = (await Dio().get(u)).data;
                                        } catch (e) {
                                          isLoadingDL.value = false;
                                          return;
                                        }
                                        if (response.isNotEmpty &&
                                            context.mounted) {
                                          await showDialog(
                                            context: context,
                                            builder: (BuildContext context) =>
                                                DownloadDialog(
                                              response,
                                              appIcon(50),
                                              (checkmap) => downloadApp(
                                                  context, checkmap, ref),
                                            ),
                                          );
                                        } else {
                                          url.launchIt();
                                        }
                                        isLoadingDL.value = false;
                                      }
                                    : null,
                            child: Text(AppLocalizations.of(context)!.download),
                          )
                      ],
                    ),
                    const Gap(25),
                  ],
                ),
              ),
            ),
          ),
          const Gap(20),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(children: [
                if (app.screenshotsUrl != null &&
                    app.screenshotsUrl!.isNotEmpty)
                  CarouselSlider.builder(
                    carouselController: _controller,
                    itemCount: app.screenshotsUrl!.length,
                    itemBuilder: (context, index, i) {
                      String screenUrl =
                          app.screenshotsUrl![index].startsWith('http')
                              ? app.screenshotsUrl![index]
                              : prefixUrl + app.screenshotsUrl![index];
                      return Container(
                        height: 400,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: app.screenshotsUrl != null
                            ? screenUrl.endsWith('.svg')
                                ? SvgPicture.network(screenUrl)
                                : CachedNetworkImage(
                                    imageUrl: screenUrl,
                                    placeholder: (c, b) => const SizedBox(),
                                    errorWidget: (c, w, i) => brokenImageWidget,
                                  )
                            : Container(),
                      );
                    },
                    options: CarouselOptions(
                        height: 400,
                        viewportFraction: 0.8,
                        initialPage: 0,
                        enableInfiniteScroll: true,
                        reverse: false,
                        autoPlay: app.screenshotsUrl!.length > 1,
                        autoPlayInterval: const Duration(seconds: 5),
                        autoPlayAnimationDuration:
                            const Duration(milliseconds: 800),
                        autoPlayCurve: Curves.fastOutSlowIn,
                        enlargeCenterPage: true,
                        scrollDirection: Axis.horizontal,
                        onPageChanged: (idx, rsn) {
                          current.value = idx;
                        }),
                  ),
                const Gap(5),
                if (app.screenshotsUrl != null &&
                    app.screenshotsUrl!.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:
                        List.generate(app.screenshotsUrl!.length, (index) {
                      return GestureDetector(
                        onTap: () => _controller.animateToPage(index),
                        child: Container(
                          width: 10.0,
                          height: 10.0,
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 2.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current.value == index
                                ? (context.isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.9)
                                : (context.isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.4),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const Gap(20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
                  child: SelectableText.rich(HTML.toTextSpan(
                      context,
                      (app.description != null &&
                              app.description!.toString().trim().isNotEmpty)
                          ? app.description!
                          : AppLocalizations.of(context)!.noDescriptionFound,
                      defaultTextStyle: context.textTheme.bodyLarge!)),
                ),
                ApTile(
                  title: AppLocalizations.of(context)!.license,
                  trailing:
                      app.license ?? AppLocalizations.of(context)!.notAvailable,
                ),
                ApTile(
                  title: AppLocalizations.of(context)!.authors,
                  trailing: app.authors != null
                      ? app.authors!
                          .map((e) => '<a href="${e['url']}" >${e['name']}</a>')
                          .join(', ')
                      : AppLocalizations.of(context)!.notAvailable,
                ),
              ]),
            ),
          )
        ],
      ),
    );
  }
}

class DownloadDialog extends StatefulHookWidget {
  final List response;
  final Widget appIcon;
  final void Function(Map<String, String>)? onEndPressed;

  const DownloadDialog(this.response, this.appIcon, this.onEndPressed,
      {Key? key})
      : super(key: key);

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  @override
  Widget build(BuildContext context) {
    final checkmap = useState<Map<String, String>>({});
    final downloadItems = DownloadItem.fromItems(widget.response);

    return CustomDialogBox(
      downloadItems: downloadItems,
      onVersionChange: (version) {
        checkmap.value = {};
      },
      items: (index) {
        var releaseItems = downloadItems[index].items;
        return List.generate(releaseItems.length, (idx) {
          var checkedValue =
              useState(checkmap.value.containsKey(releaseItems[idx].url));
          checkmap.addListener(() {
            checkedValue.value =
                checkmap.value.containsKey(releaseItems[idx].url);
          });
          return CheckboxListTile(
            title: Text(releaseItems[idx].name),
            subtitle: Text(releaseItems[idx].size.getFileSize()),
            value: checkedValue.value,
            onChanged: (newValue) {
              if (checkmap.value.containsKey(releaseItems[idx].url)) {
                checkmap.value
                    .removeWhere((key, value) => key == releaseItems[idx].url);
              } else {
                checkmap.value.putIfAbsent(
                    releaseItems[idx].url, () => releaseItems[idx].name);
              }
              // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
              checkmap.notifyListeners();
            },
          );
        });
      },
      endItem: widget.onEndPressed != null && checkmap.value.isNotEmpty
          ? AdwButton(
              onPressed: () async {
                widget.onEndPressed!(checkmap.value);
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)!.download,
                style: const TextStyle(fontSize: 18),
              ),
            )
          : null,
      img: widget.appIcon,
    );
  }
}
