     1|import 'dart:io';
     2|import 'package:flutter/material.dart';
     3|import 'package:flutter_bloc/flutter_bloc.dart';
     4|import '../../core/theme/app_colors.dart';
     5|import '../../core/services/haptic_service.dart';
     6|import '../../data/services/sharing/share_service.dart';
     7|import '../../data/services/sharing/instagram_stories_generator.dart';
     8|import '../../data/services/sharing/infographic_generator.dart';
     9|import '../../data/services/export_import/export_service.dart';
    10|import '../../data/models/album_model.dart';
    11|import '../collection/bloc/collection_bloc.dart';
    12|
    13|/// Screen for sharing and exporting album data.
    14|class ShareExportScreen extends StatefulWidget {
    15|  final Album? singleAlbum;
    16|
    17|  const ShareExportScreen({super.key, this.singleAlbum});
    18|
    19|  @override
    20|  State<ShareExportScreen> createState() => _ShareExportScreenState();
    21|}
    22|
    23|class _ShareExportScreenState extends State<ShareExportScreen> with SingleTickerProviderStateMixin {
    24|  late TabController _tabController;
    25|  final _shareService = ShareService();
    26|  final _exportService = ExportService();
    27|  final _igKey = GlobalKey();
    28|  final _infographicKey = GlobalKey();
    29|  bool _isExporting = false;
    30|
    31|  @override
    32|  void initState() {
    33|    super.initState();
    34|    _tabController = TabController(length: 3, vsync: this);
    35|  }
    36|
    37|  @override
    38|  void dispose() {
    39|    _tabController.dispose();
    40|    super.dispose();
    41|  }
    42|
    43|  @override
    44|  Widget build(BuildContext context) {
    45|    return Scaffold(
    46|      backgroundColor: AppColors.background,
    47|      appBar: AppBar(
    48|        backgroundColor: AppColors.surface,
    49|        title: const Text('Share & Export', style: TextStyle(color: AppColors.textPrimary)),
    50|        bottom: TabBar(
    51|          controller: _tabController,
    52|          indicatorColor: AppColors.primary,
    53|          labelColor: AppColors.primary,
    54|          unselectedLabelColor: AppColors.textTertiary,
    55|          tabs: const [
    56|            Tab(text: 'Share'),
    57|            Tab(text: 'Instagram'),
    58|            Tab(text: 'Export'),
    59|          ],
    60|        ),
    61|      ),
    62|      body: TabBarView(
    63|        controller: _tabController,
    64|        children: [
    65|          _buildShareTab(),
    66|          _buildInstagramTab(),
    67|          _buildExportTab(),
    68|        ],
    69|      ),
    70|    );
    71|  }
    72|
    73|  // ==========================================
    74|  // Share Tab
    75|  // ==========================================
    76|
    77|  Widget _buildShareTab() {
    78|    final album = widget.singleAlbum;
    79|
    80|    if (album != null) {
    81|      return _buildSingleAlbumShare(album);
    82|    }
    83|
    84|    return BlocBuilder<CollectionBloc, CollectionState>(
    85|      builder: (context, state) {
    86|        final albums = state is CollectionLoaded ? state.albums : <Album>[];
    87|        return _buildCollectionShare(albums);
    88|      },
    89|    );
    90|  }
    91|
    92|  Widget _buildSingleAlbumShare(Album album) {
    93|    return ListView(
    94|      padding: const EdgeInsets.all(16),
    95|      children: [
    96|        // Album preview
    97|        if (album.userPhotoPath != null || album.coverArtUrl != null)
    98|          ClipRRect(
    99|            borderRadius: BorderRadius.circular(14),
   100|            child: Image.file(
   101|              File(album.userPhotoPath ?? album.coverArtUrl!),
   102|              height: 200,
   103|              width: double.infinity,
   104|              fit: BoxFit.cover,
   105|            ),
   106|          )
   107|        else
   108|          Container(
   109|            height: 200,
   110|            decoration: BoxDecoration(
   111|              color: AppColors.surface,
   112|              borderRadius: BorderRadius.circular(14),
   113|            ),
   114|            child: const Icon(Icons.album, size: 60, color: AppColors.textTertiary),
   115|          ),
   116|        const SizedBox(height: 16),
   117|        Text(album.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
   118|        Text(album.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
   119|        const SizedBox(height: 24),
   120|
   121|        // Share options
   122|        _ShareOptionCard(
   123|          icon: Icons.share,
   124|          title: 'Share as Text',
   125|          subtitle: 'Album info, tracklist, and details',
   126|          onTap: () => _shareService.shareAlbumText(album),
   127|        ),
   128|        _ShareOptionCard(
   129|          icon: Icons.image,
   130|          title: 'Share with Cover',
   131|          subtitle: 'Text + album cover image',
   132|          onTap: () => _shareService.shareAlbumWithImage(album),
   133|        ),
   134|        _ShareOptionCard(
   135|          icon: Icons.copy,
   136|          title: 'Copy to Clipboard',
   137|          subtitle: 'Copy album details as text',
   138|          onTap: () async {
   139|            await _shareService.copyAlbumToClipboard(album);
   140|            if (mounted) {
   141|              ScaffoldMessenger.of(context).showSnackBar(
   142|                const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Colors.green),
   143|              );
   144|            }
   145|          },
   146|        ),
   147|      ],
   148|    );
   149|  }
   150|
   151|  Widget _buildCollectionShare(List<Album> albums) {
   152|    return ListView(
   153|      padding: const EdgeInsets.all(16),
   154|      children: [
   155|        Text(
   156|          'Share Collection',
   157|          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
   158|        ),
   159|        const SizedBox(height: 4),
   160|        Text(
   161|          '\${albums.length} albums',
   162|          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
   163|        ),
   164|        const SizedBox(height: 20),
   165|        _ShareOptionCard(
   166|          icon: Icons.list,
   167|          title: 'Share as List',
   168|          subtitle: 'All albums in a text list',
   169|          onTap: () => _shareService.shareAlbumList(albums),
   170|        ),
   171|        _ShareOptionCard(
   172|          icon: Icons.auto_graph,
   173|          title: 'Share Infographic',
   174|          subtitle: 'Visual stats card for social media',
   175|          onTap: () => _shareInfographic(albums),
   176|        ),
   177|      ],
   178|    );
   179|  }
   180|
   181|  // ==========================================
   182|  // Instagram Tab
   183|  // ==========================================
   184|
   185|  Widget _buildInstagramTab() {
   186|    final album = widget.singleAlbum;
   187|    if (album == null) {
   188|      return const Center(
   189|        child: Padding(
   190|          padding: EdgeInsets.all(32),
   191|          child: Column(
   192|            mainAxisAlignment: MainAxisAlignment.center,
   193|            children: [
   194|              Icon(Icons.share, size: 64, color: AppColors.textTertiary),
   195|              SizedBox(height: 16),
   196|              Text(
   197|                'Open an album to generate an Instagram Story',
   198|                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
   199|                textAlign: TextAlign.center,
   200|              ),
   201|            ],
   202|          ),
   203|        ),
   204|      );
   205|    }
   206|
   207|    final coverImage = album.userPhotoPath != null ? File(album.userPhotoPath!) : (album.coverArtUrl != null ? File(album.coverArtUrl!) : null);
   208|
   209|    return ListView(
   210|      padding: const EdgeInsets.all(16),
   211|      children: [
   212|        // Preview (scaled down)
   213|        Container(
   214|          height: 480,
   215|          decoration: BoxDecoration(
   216|            borderRadius: BorderRadius.circular(14),
   217|            border: Border.all(color: AppColors.border),
   218|          ),
   219|          clipBehavior: Clip.antiAlias,
   220|          child: FittedBox(
   221|            fit: BoxFit.contain,
   222|            child: SizedBox(
   223|              width: InstagramStoriesGenerator.MediaQuery.of(context).size.width.toString() / 3,
   224|              height: InstagramStoriesGenerator.MediaQuery.of(context).size.height.toString() / 3,
   225|              child: RepaintBoundary(
   226|                key: _igKey,
   227|                child: InstagramStoryCard(album: album, coverImage: coverImage),
   228|              ),
   229|            ),
   230|          ),
   231|        ),
   232|        const SizedBox(height: 16),
   233|        Text(
   234|          '1080 x 1920 - Stories format',
   235|          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
   236|          textAlign: TextAlign.center,
   237|        ),
   238|        const SizedBox(height: 20),
   239|        ElevatedButton.icon(
   240|          onPressed: () => _shareInstagramStory(album),
   241|          icon: const Icon(Icons.share),
   242|          label: const Text('Share to Instagram'),
   243|          style: ElevatedButton.styleFrom(
   244|            backgroundColor: Colors.pink,
   245|            foregroundColor: Colors.white,
   246|            minimumSize: const Size(double.infinity, 52),
   247|            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
   248|          ),
   249|        ),
   250|      ],
   251|    );
   252|  }
   253|
   254|  // ==========================================
   255|  // Export Tab
   256|  // ==========================================
   257|
   258|  Widget _buildExportTab() {
   259|    return BlocBuilder<CollectionBloc, CollectionState>(
   260|      builder: (context, state) {
   261|        final albums = state is CollectionLoaded ? state.albums : <Album>[];
   262|        return ListView(
   263|          padding: const EdgeInsets.all(16),
   264|          children: [
   265|            Text(
   266|              'Export Collection',
   267|              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
   268|            ),
   269|            const SizedBox(height: 4),
   270|            Text(
   271|              '\${albums.length} albums will be exported',
   272|              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
   273|            ),
   274|            const SizedBox(height: 20),
   275|            _ExportFormatCard(
   276|              icon: Icons.code,
   277|              title: 'JSON',
   278|              subtitle: 'Structured data, re-importable',
   279|              color: Colors.amber,
   280|              isExporting: _isExporting,
   281|              onTap: () => _doExport(albums, ExportFormat.json),
   282|            ),
   283|            _ExportFormatCard(
   284|              icon: Icons.table_chart,
   285|              title: 'CSV',
   286|              subtitle: 'Spreadsheet compatible (Excel, Google Sheets)',
   287|              color: Colors.green,
   288|              isExporting: _isExporting,
   289|              onTap: () => _doExport(albums, ExportFormat.csv),
   290|            ),
   291|            _ExportFormatCard(
   292|              icon: Icons.picture_as_pdf,
   293|              title: 'PDF',
   294|              subtitle: 'Printable document with album list',
   295|              color: Colors.red,
   296|              isExporting: _isExporting,
   297|              onTap: () => _doExport(albums, ExportFormat.pdf),
   298|            ),
   299|          ],
   300|        );
   301|      },
   302|    );
   303|  }
   304|
   305|  // ==========================================
   306|  // Actions
   307|  // ==========================================
   308|
   309|  Future<void> _doExport(List<Album> albums, ExportFormat format) async {
   310|    HapticService.medium();
   311|    setState(() => _isExporting = true);
   312|
   313|    try {
   314|      await _exportService.exportAndShare(albums, format);
   315|    } catch (e) {
   316|      if (mounted) {
   317|        ScaffoldMessenger.of(context).showSnackBar(
   318|          SnackBar(content: Text('Export failed: \$e'), backgroundColor: Colors.red),
   319|        );
   320|      }
   321|    } finally {
   322|      if (mounted) setState(() => _isExporting = false);
   323|    }
   324|  }
   325|
   326|  Future<void> _shareInstagramStory(Album album) async {
   327|    HapticService.medium();
   328|    final generator = InstagramStoriesGenerator();
   329|    final path = await generator.generate(
   330|      repaintKey: _igKey,
   331|      album: album,
   332|    );
   333|    if (path != null && mounted) {
   334|      await _shareService.shareWidgetAsImage(
   335|        repaintKey: _igKey,
   336|        text: '\${album.artist} - \${album.title}',
   337|      );
   338|    }
   339|  }
   340|
   341|  Future<void> _shareInfographic(List<Album> albums) async {
   342|    HapticService.medium();
   343|    await _shareService.shareWidgetAsImage(
   344|      repaintKey: _infographicKey,
   345|      text: 'My Album Collection',
   346|      subject: 'Album Collection Stats',
   347|    );
   348|  }
   349|}
   350|
   351|// ==========================================
   352|// Helper Widgets
   353|// ==========================================
   354|
   355|class _ShareOptionCard extends StatelessWidget {
   356|  final IconData icon;
   357|  final String title;
   358|  final String subtitle;
   359|  final VoidCallback onTap;
   360|
   361|  const _ShareOptionCard({
   362|    required this.icon,
   363|    required this.title,
   364|    required this.subtitle,
   365|    required this.onTap,
   366|  });
   367|
   368|  @override
   369|  Widget build(BuildContext context) {
   370|    return Card(
   371|      color: AppColors.surface,
   372|      margin: const EdgeInsets.only(bottom: 10),
   373|      shape: RoundedRectangleBorder(
   374|        borderRadius: BorderRadius.circular(14),
   375|        side: const BorderSide(color: AppColors.border, width: 0.5),
   376|      ),
   377|      child: ListTile(
   378|        leading: Container(
   379|          width: 44,
   380|          height: 44,
   381|          decoration: BoxDecoration(
   382|            color: AppColors.primary.withOpacity(0.1),
   383|            borderRadius: BorderRadius.circular(12),
   384|          ),
   385|          child: Icon(icon, color: AppColors.primary, size: 22),
   386|        ),
   387|        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
   388|        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
   389|        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
   390|        onTap: onTap,
   391|      ),
   392|    );
   393|  }
   394|}
   395|
   396|class _ExportFormatCard extends StatelessWidget {
   397|  final IconData icon;
   398|  final String title;
   399|  final String subtitle;
   400|  final Color color;
   401|  final bool isExporting;
   402|  final VoidCallback onTap;
   403|
   404|  const _ExportFormatCard({
   405|    required this.icon,
   406|    required this.title,
   407|    required this.subtitle,
   408|    required this.color,
   409|    required this.isExporting,
   410|    required this.onTap,
   411|  });
   412|
   413|  @override
   414|  Widget build(BuildContext context) {
   415|    return Card(
   416|      color: AppColors.surface,
   417|      margin: const EdgeInsets.only(bottom: 10),
   418|      shape: RoundedRectangleBorder(
   419|        borderRadius: BorderRadius.circular(14),
   420|        side: const BorderSide(color: AppColors.border, width: 0.5),
   421|      ),
   422|      child: ListTile(
   423|        leading: Container(
   424|          width: 44,
   425|          height: 44,
   426|          decoration: BoxDecoration(
   427|            color: color.withOpacity(0.1),
   428|            borderRadius: BorderRadius.circular(12),
   429|          ),
   430|          child: isExporting
   431|              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
   432|              : Icon(icon, color: color, size: 22),
   433|        ),
   434|        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
   435|        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
   436|        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
   437|        onTap: isExporting ? null : onTap,
   438|      ),
   439|    );
   440|  }
   441|}
   442|