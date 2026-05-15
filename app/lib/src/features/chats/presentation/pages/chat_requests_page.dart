import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ChatRequestsPage extends StatelessWidget {
  const ChatRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatScaffold(
      appBar: ChatTitleAppBar(
        title: 'Requests',
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textBrand,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.chats),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ChatSectionLabel(label: 'Requests'),
            const Gap(24),
            Text(
              'Заявки в сообщения пока не подключены к API. '
              'Когда бэкенд отдаст список, он появится здесь.',
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.textBrand.withValues(alpha: 0.56),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
