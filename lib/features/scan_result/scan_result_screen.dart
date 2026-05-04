     1|import 'dart:io';
     2|import 'package:flutter/material.dart';
     3|import 'package:flutter_bloc/flutter_bloc.dart';
     4|import '../../core/theme/app_colors.dart';
     5|import '../../data/models/album_model.dart';
     6|import 'bloc/scan_result_bloc.dart';
     7|import 'manual_search_screen.dart';
     8|
     9|/// Displays recognition results with pipeline visualization.
    10|class ScanResultScreen extends StatefulWidget {
    11|  final String imagePath;
    12|
    13|  const ScanResultScreen({super.key, required this.imagePath});
    14|
    15|  @override
    16|  State<ScanResultScreen> createState() => _ScanResultScreenState();
    17|}
    18|
    19|class _ScanResultScreenState extends State<ScanResultScreen>
    20|    with SingleTickerProviderStateMixin {
    21|  late AnimationController _pulseController;
    22|
    23|  @override
    24|  void initState() {
    25|    super.initState();
    26|    _pulseController = AnimationController(
    27|      vsync: this,
    28|      duration: const Duration(seconds: 2),
    29|    )..repeat();
    30|    // Auto-start recognition
    31|    Future.microtask(() {
    32|      context.read<ScanResultBloc>().add(StartRecognition(widget.imagePath));
    33|    });
    34|  }
    35|
    36|  @override
    37|  void dispose() {
    38|    _pulseController.dispose();
    39|    super.dispose();
    40|  }
    41|
    42|  @override
    43|  Widget build(BuildContext context) {
    44|    return Scaffold(
    45|      backgroundColor: AppColors.background,
    46|      appBar: AppBar(
    47|        leading: IconButton(
    48|          icon: const Icon(Icons.close),
    49|          onPressed: () {
    50|            context.read<ScanResultBloc>().add(CancelRecognition());
    51|            Navigator.of(context).pop();
    52|          },
    53|        ),
    54|        title: const Text('Recognition'),
    55|      ),
    56|      body: BlocConsumer<ScanResultBloc, ScanResultState>(
    57|        listener: (context, state) {
    58|          if (state is ScanResultSaved) {
    59|            ScaffoldMessenger.of(context).showSnackBar(
    60|              SnackBar(
    61|                content: Text('"${state.album.title}" added to collection!'),
    62|                backgroundColor: AppColors.success,
    63|                behavior: SnackBarBehavior.floating,
    64|              ),
    65|            );
    66|            Navigator.of(context).pop();
    67|          }
    68|        },
    69|        builder: (context, state) {
    70|          return AnimatedSwitcher(
    71|            duration: const Duration(milliseconds: 300),
    72|            child: switch (state) {
    73|              ScanResultProcessing() => _buildProcessing(state),
    74|              ScanResultSuccess() => _buildResult(state),
    75|              ScanResultFailure() => _buildFailure(state),
    76|              ScanResultSaved() => _buildProcessing(
    77|                  const ScanResultProcessing(currentStep: 'Saving...')),
    78|              _ => _buildProcessing(
    79|                  const ScanResultProcessing(currentStep: 'Starting...')),
    80|            },
    81|          );
    82|        },
    83|      ),
    84|    );
    85|  }
    86|
    87|  // ==========================================
    88|  // Processing State
    89|  // ==========================================
    90|
    91|  Widget _buildProcessing(ScanResultProcessing state) {
    92|    return Center(
    93|      child: Padding(
    94|        padding: const EdgeInsets.all(32),
    95|        child: Column(
    96|          mainAxisSize: MainAxisSize.min,
    97|          children: [
    98|            // Photo with scanning animation
    99|            Stack(
   100|              alignment: Alignment.center,
   101|              children: [
   102|                ClipRRect(
   103|                  borderRadius: BorderRadius.circular(16),
   104|                  child: Image.file(
   105|                    File(widget.imagePath),
   106|                    width: 220,
   107|                    height: 220,
   108|                    fit: BoxFit.cover,
   109|                  ),
   110|                ),
   111|                // Scanning overlay
   112|                AnimatedBuilder(
        animation: AlwaysStoppedAnimation(1.0),
   113|                  animation: _pulseController,
   114|                  builder: (context, child) {
   115|                    return Container(
   116|                      width: 220,
   117|                      height: 220,
   118|                      decoration: BoxDecoration(
   119|                        borderRadius: BorderRadius.circular(16),
   120|                        border: Border.all(
   121|                          color: AppColors.primary
   122|                              .withOpacity(0.5 + 0.5 * _pulseController.value),
   123|                          width: 2,
   124|                        ),
   125|                      ),
   126|                    );
   127|                  },
   128|                ),
   129|              ],
   130|            ),
   131|            const SizedBox(height: 32),
   132|
   133|            // Progress indicator
   134|            if (state.totalSteps > 0) ...[
   135|              ClipRRect(
   136|                borderRadius: BorderRadius.circular(4),
   137|                child: LinearProgressIndicator(
   138|                  value: state.progress,
   139|                  backgroundColor: AppColors.surfaceLight,
   140|                  color: AppColors.primary,
   141|                  minHeight: 6,
   142|                ),
   143|              ),
   144|              const SizedBox(height: 12),
   145|            ],
   146|
   147|            // Current step label
   148|            Text(
   149|              state.currentStep ?? 'Analyzing...',
   150|              style: const TextStyle(
   151|                color: AppColors.textSecondary,
   152|                fontSize: 16,
   153|              ),
   154|            ),
   155|            const SizedBox(height: 8),
   156|
   157|            // Step dots
   158|            Row(
   159|              mainAxisAlignment: MainAxisAlignment.center,
   160|              children: List.generate(
   161|                4,
   162|                (i) => Container(
   163|                  width: 8,
   164|                  height: 8,
   165|                  margin: const EdgeInsets.symmetric(horizontal: 4),
   166|                  decoration: BoxDecoration(
   167|                    shape: BoxShape.circle,
   168|                    color: i < state.stepsCompleted
   169|                        ? AppColors.primary
   170|                        : AppColors.surfaceLight,
   171|                  ),
   172|                ),
   173|              ),
   174|            ),
   175|          ],
   176|        ),
   177|      ),
   178|    );
   179|  }
   180|
   181|  // ==========================================
   182|  // Success State
   183|  // ==========================================
   184|
   185|  Widget _buildResult(ScanResultSuccess state) {
   186|    return SingleChildScrollView(
   187|      padding: const EdgeInsets.all(16),
   188|      child: Column(
   189|        crossAxisAlignment: CrossAxisAlignment.start,
   190|        children: [
   191|          // Cover + confidence
   192|          _buildCoverWithBadge(state),
   193|          const SizedBox(height: 20),
   194|
   195|          // Pipeline summary
   196|          if (state.pipelineSummary != null)
   197|            _buildPipelineSummary(state.pipelineSummary!),
   198|          if (state.pipelineSummary != null)
   199|            const SizedBox(height: 16),
   200|
   201|          // Extracted text (debug / info)
   202|          if (state.extractedText != null && state.extractedText!.isNotEmpty)
   203|            _buildExtractedTextCard(state.extractedText!),
   204|          if (state.extractedText != null && state.extractedText!.isNotEmpty)
   205|            const SizedBox(height: 16),
   206|
   207|          // Album info card
   208|          _buildInfoCard(state.album, state.source),
   209|          const SizedBox(height: 20),
   210|
   211|          // Tracklist
   212|          if (state.album.tracklist.isNotEmpty) ...[
   213|            _buildTracklist(state.album.tracklist),
   214|            const SizedBox(height: 20),
   215|          ],
   216|
   217|          // Save button
   218|          _buildSaveButton(state.album),
   219|          const SizedBox(height: 12),
   220|
   221|          // Retry button
   222|          _buildRetryButton(),
   223|          const SizedBox(height: 24),
   224|        ],
   225|      ),
   226|    );
   227|  }
   228|
   229|  Widget _buildCoverWithBadge(ScanResultSuccess state) {
   230|    return Center(
   231|      child: Stack(
   232|        children: [
   233|          ClipRRect(
   234|            borderRadius: BorderRadius.circular(16),
   235|            child: state.album.userPhotoPath != null
   236|                ? Image.file(
   237|                    File(state.album.userPhotoPath!),
   238|                    width: 240,
   239|                    height: 240,
   240|                    fit: BoxFit.cover,
   241|                  )
   242|                : Container(
   243|                    width: 240,
   244|                    height: 240,
   245|                    color: AppColors.surfaceLight,
   246|                    child: const Icon(Icons.album, size: 64, color: AppColors.textTertiary),
   247|                  ),
   248|          ),
   249|          Positioned(
   250|            top: 8,
   251|            right: 8,
   252|            child: Container(
   253|              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
   254|              decoration: BoxDecoration(
   255|                color: state.confidence >= 0.8
   256|                    ? AppColors.success
   257|                    : state.confidence >= 0.6
   258|                        ? AppColors.warning
   259|                        : AppColors.error,
   260|                borderRadius: BorderRadius.circular(10),
   261|                boxShadow: [
   262|                  BoxShadow(
   263|                    color: Colors.black.withOpacity(0.3),
   264|                    blurRadius: 4,
   265|                  ),
   266|                ],
   267|              ),
   268|              child: Text(
   269|                '${(state.confidence * 100).toInt()}%',
   270|                style: const TextStyle(
   271|                  color: Colors.white,
   272|                  fontWeight: FontWeight.w700,
   273|                  fontSize: 13,
   274|                ),
   275|              ),
   276|            ),
   277|          ),
   278|          Positioned(
   279|            bottom: 8,
   280|            left: 8,
   281|            child: Container(
   282|              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
   283|              decoration: BoxDecoration(
   284|                color: AppColors.background.withOpacity(0.8),
   285|                borderRadius: BorderRadius.circular(8),
   286|              ),
   287|              child: Row(
   288|                mainAxisSize: MainAxisSize.min,
   289|                children: [
   290|                  Icon(
   291|                    state.source == 'Barcode' ? Icons.qr_code : Icons.cloud,
   292|                    size: 12,
   293|                    color: AppColors.primaryLight,
   294|                  ),
   295|                  const SizedBox(width: 4),
   296|                  Text(
   297|                    state.source,
   298|                    style: const TextStyle(
   299|                      color: AppColors.primaryLight,
   300|                      fontSize: 11,
   301|                      fontWeight: FontWeight.w600,
   302|                    ),
   303|                  ),
   304|                ],
   305|              ),
   306|            ),
   307|          ),
   308|        ],
   309|      ),
   310|    );
   311|  }
   312|
   313|  Widget _buildPipelineSummary(String summary) {
   314|    return Container(
   315|      padding: const EdgeInsets.all(12),
   316|      decoration: BoxDecoration(
   317|        color: AppColors.surface,
   318|        borderRadius: BorderRadius.circular(10),
   319|      ),
   320|      child: Row(
   321|        children: [
   322|          const Icon(Icons.route, size: 16, color: AppColors.textTertiary),
   323|          const SizedBox(width: 8),
   324|          Expanded(
   325|            child: Text(
   326|              summary,
   327|              style: const TextStyle(
   328|                color: AppColors.textTertiary,
   329|                fontSize: 11,
   330|                fontFamily: 'monospace',
   331|              ),
   332|              maxLines: 2,
   333|              overflow: TextOverflow.ellipsis,
   334|            ),
   335|          ),
   336|        ],
   337|      ),
   338|    );
   339|  }
   340|
   341|  Widget _buildExtractedTextCard(String text) {
   342|    return Container(
   343|      padding: const EdgeInsets.all(12),
   344|      decoration: BoxDecoration(
   345|        color: AppColors.surface,
   346|        borderRadius: BorderRadius.circular(10),
   347|        border: Border.all(color: AppColors.border, width: 0.5),
   348|      ),
   349|      child: Column(
   350|        crossAxisAlignment: CrossAxisAlignment.start,
   351|        children: [
   352|          const Row(
   353|            children: [
   354|              Icon(Icons.text_fields, size: 14, color: AppColors.textTertiary),
   355|              SizedBox(width: 6),
   356|              Text(
   357|                'Extracted Text',
   358|                style: TextStyle(
   359|                  color: AppColors.textTertiary,
   360|                  fontSize: 12,
   361|                  fontWeight: FontWeight.w600,
   362|                ),
   363|              ),
   364|            ],
   365|          ),
   366|          const SizedBox(height: 6),
   367|          Text(
   368|            text.length > 200 ? '${text.substring(0, 200)}...' : text,
   369|            style: const TextStyle(
   370|              color: AppColors.textSecondary,
   371|              fontSize: 12,
   372|            ),
   373|          ),
   374|        ],
   375|      ),
   376|    );
   377|  }
   378|
   379|  Widget _buildInfoCard(Album album, String source) {
   380|    return Container(
   381|      width: double.infinity,
   382|      padding: const EdgeInsets.all(16),
   383|      decoration: BoxDecoration(
   384|        color: AppColors.cardBackground,
   385|        borderRadius: BorderRadius.circular(16),
   386|        border: Border.all(color: AppColors.border, width: 0.5),
   387|      ),
   388|      child: Column(
   389|        crossAxisAlignment: CrossAxisAlignment.start,
   390|        children: [
   391|          Text(
   392|            album.title,
   393|            style: const TextStyle(
   394|              color: AppColors.textPrimary,
   395|              fontSize: 22,
   396|              fontWeight: FontWeight.w700,
   397|            ),
   398|          ),
   399|          const SizedBox(height: 4),
   400|          Text(
   401|            album.artist,
   402|            style: const TextStyle(
   403|              color: AppColors.primaryLight,
   404|              fontSize: 16,
   405|              fontWeight: FontWeight.w500,
   406|            ),
   407|          ),
   408|          const SizedBox(height: 12),
   409|          if (album.releaseYear != null)
   410|            _buildInfoRow(Icons.calendar_today, '${album.releaseYear}'),
   411|          if (album.label != null)
   412|            _buildInfoRow(Icons.label, album.label!),
   413|          if (album.genre != null)
   414|            _buildInfoRow(Icons.music_note, album.genre!),
   415|          if (album.country != null)
   416|            _buildInfoRow(Icons.flag, album.country!),
   417|          if (album.barcode != null)
   418|            _buildInfoRow(Icons.qr_code, album.barcode!),
   419|        ],
   420|      ),
   421|    );
   422|  }
   423|
   424|  Widget _buildInfoRow(IconData icon, String text) {
   425|    return Padding(
   426|      padding: const EdgeInsets.symmetric(vertical: 2),
   427|      child: Row(
   428|        children: [
   429|          Icon(icon, size: 14, color: AppColors.textTertiary),
   430|          const SizedBox(width: 8),
   431|          Flexible(
   432|            child: Text(
   433|              text,
   434|              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
   435|              overflow: TextOverflow.ellipsis,
   436|            ),
   437|          ),
   438|        ],
   439|      ),
   440|    );
   441|  }
   442|
   443|  Widget _buildTracklist(List<String> tracks) {
   444|    return Column(
   445|      crossAxisAlignment: CrossAxisAlignment.start,
   446|      children: [
   447|        Row(
   448|          children: [
   449|            const Text(
   450|              'Tracklist',
   451|              style: TextStyle(
   452|                color: AppColors.textPrimary,
   453|                fontSize: 18,
   454|                fontWeight: FontWeight.w600,
   455|              ),
   456|            ),
   457|            const SizedBox(width: 8),
   458|            Container(
   459|              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
   460|              decoration: BoxDecoration(
   461|                color: AppColors.surfaceLight,
   462|                borderRadius: BorderRadius.circular(10),
   463|              ),
   464|              child: Text(
   465|                '${tracks.length}',
   466|                style: const TextStyle(
   467|                  color: AppColors.textTertiary,
   468|                  fontSize: 12,
   469|                ),
   470|              ),
   471|            ),
   472|          ],
   473|        ),
   474|        const SizedBox(height: 8),
   475|        ...tracks.asMap().entries.map((entry) => Padding(
   476|              padding: const EdgeInsets.symmetric(vertical: 4),
   477|              child: Row(
   478|                children: [
   479|                  SizedBox(
   480|                    width: 28,
   481|                    child: Text(
   482|                      '${entry.key + 1}',
   483|                      style: const TextStyle(
   484|                        color: AppColors.textTertiary,
   485|                        fontSize: 13,
   486|                      ),
   487|                    ),
   488|                  ),
   489|                  Expanded(
   490|                    child: Text(
   491|                      entry.value,
   492|                      style: const TextStyle(
   493|                        color: AppColors.textSecondary,
   494|                        fontSize: 14,
   495|                      ),
   496|                    ),
   497|                  ),
   498|                ],
   499|              ),
   500|            )),
   501|