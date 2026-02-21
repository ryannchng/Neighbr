import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../repositories/business_request_repository.dart';

class WriteRequestScreen extends StatefulWidget {
  const WriteRequestScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<WriteRequestScreen> createState() => _WriteRequestScreenState();
}

class _WriteRequestScreenState extends State<WriteRequestScreen> {
  final _repo = BusinessRequestRepository();
  final _requestController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _neededBy;
  bool _submitting = false;
  bool get _isGuest => SupabaseClientProvider.currentUser?.isAnonymous ?? false;

  @override
  void dispose() {
    _requestController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _neededBy = picked);
  }

  Future<void> _submit() async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guests cannot submit requests.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = _requestController.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a few more details to your request.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : double.tryParse(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget must be a valid number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.createRequest(
        businessId: widget.businessId,
        requestText: text,
        maxBudget: budget,
        neededBy: _neededBy,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request posted. Businesses can now take it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post request. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Write a request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(
            'Describe what you need',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _requestController,
            minLines: 4,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText:
                  'Example: Willing to cater my son\'s birthday this Sunday for under \$70.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Max budget (optional)',
              hintText: '70',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _neededBy == null
                  ? 'When do you need this? (optional)'
                  : 'Needed by: ${_neededBy!.month}/${_neededBy!.day}/${_neededBy!.year}',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (_submitting || _isGuest) ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.campaign_outlined),
            label: Text(_isGuest ? 'Unavailable for guests' : 'Post request'),
          ),
        ],
      ),
    );
  }
}
