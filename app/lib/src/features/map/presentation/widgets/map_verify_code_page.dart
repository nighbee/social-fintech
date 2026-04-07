part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _VerifyCodePage extends StatefulWidget {
  const _VerifyCodePage({
    required this.mapBloc,
    required this.taskId,
    required this.applicationId,
  });

  final MapBloc mapBloc;
  final String taskId;
  final String applicationId;

  @override
  State<_VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<_VerifyCodePage> {
  String _code = '';
  bool _isSubmitting = false;
  bool _hasInvalidCodeError = false;

  bool get _isCodeComplete =>
      _code.length == 4 && !_code.contains(RegExp(r'[^0-9]'));

  void _submit() {
    if (!_isCodeComplete || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _hasInvalidCodeError = false;
    });

    widget.mapBloc.add(
      MapEvent.verifyTaskApplicationCode(
        MapTaskApplicationIdRequest(
          taskId: widget.taskId,
          applicationId: widget.applicationId,
        ),
        MapVerifyCodeRequest(code: _code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: BlocListener<MapBloc, MapState>(
        bloc: widget.mapBloc,
        listener: (context, state) {
          state.maybeWhen(
            loadingError: (_) {
              if (!_isSubmitting) {
                return;
              }
              setState(() {
                _isSubmitting = false;
                _hasInvalidCodeError = true;
              });
            },
            loaded: (viewModel) {
              final verify = viewModel.verifyCodeResult;
              if (verify.applicationId == widget.applicationId &&
                  verify.status == 'code_verified') {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
              if (_isSubmitting) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            },
            orElse: () {},
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the code',
                style: TextStyles.titleXBig.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 4-digit verification code you got from the creator.',
                style: TextStyles.bodyMain.copyWith(color: Colors.white38),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CodeInputField(
                        length: 4,
                        allowAlphanumeric: false,
                        isInvalid: _hasInvalidCodeError,
                        onChanged: (code) {
                          setState(() {
                            _code = code;
                            _hasInvalidCodeError = false;
                          });
                        },
                      ),
                      if (_hasInvalidCodeError) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 300,
                          child: Text(
                            'You entered the wrong verification code.',
                            textAlign: TextAlign.center,
                            style: TextStyles.bodyMain.copyWith(
                              color: const Color(0xFFEF4444),
                              fontSize: 16,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              CustomButton(
                text: _isSubmitting ? 'Verifying...' : 'Continue',
                onTap: _submit,
                borderRadius: 8,
                backgroundColor: _isCodeComplete
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                textStyle: TextStyles.bodyMain.copyWith(
                  color: _isCodeComplete ? Colors.black87 : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),


                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
