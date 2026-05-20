import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';

class SubmitFeedbackScreen extends ConsumerStatefulWidget {
  const SubmitFeedbackScreen({super.key});

  @override
  ConsumerState<SubmitFeedbackScreen> createState() =>
      _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState extends ConsumerState<SubmitFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedBusId;
  File? _screenshot;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _screenshot = File(picked.path));
      }
    } catch (e) {
      setState(() => _error = 'Could not pick image: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusId == null) {
      setState(() => _error = 'Please select a bus');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(feedbackRepositoryProvider).submit(
            busId: _selectedBusId!,
            description: _descriptionController.text.trim(),
            screenshot: _screenshot,
          );
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted')),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Submit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(allBusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              busesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading buses: $e'),
                data: (buses) => _busDropdown(buses),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Description is required';
                  if (t.length < 5) return 'Please add a bit more detail';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _screenshotPicker(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting…' : 'Submit'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _busDropdown(List<Bus> buses) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBusId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Bus',
        border: OutlineInputBorder(),
      ),
      items: buses
          .map((b) => DropdownMenuItem(
                value: b.id,
                child: Text(b.plateNumber, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedBusId = v),
      validator: (v) => v == null ? 'Please select a bus' : null,
    );
  }

  Widget _screenshotPicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('Screenshot (optional)'),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_screenshot == null ? 'Attach' : 'Replace'),
              ),
            ],
          ),
          if (_screenshot != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                _screenshot!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _screenshot = null),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Remove'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
