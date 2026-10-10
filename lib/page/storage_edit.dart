import 'package:file_picker/file_picker.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/android_saf.dart';
import 'package:fldanplay/utils/toast.dart';

class _StorageFormData {
  final controllers = <String, TextEditingController>{};
  final values = <String, Object?>{};

  void init(List<StorageEditField> fields) {
    dispose();
    for (final field in fields) {
      if (field.type == .text) {
        controllers[field.key] = TextEditingController(
          text: field.read()?.toString() ?? '',
        );
      } else {
        values[field.key] = field.read();
      }
    }
  }

  void save(List<StorageEditField> fields) {
    for (final field in fields) {
      final value = field.type == .text
          ? controllers[field.key]?.text.trim() ?? ''
          : values[field.key];
      field.write(value);
    }
  }

  String text(String key) => controllers[key]?.text.trim() ?? '';

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
    values.clear();
  }
}

class StorageEditPage extends StatefulWidget {
  final String? storageKey;
  final StorageType storageType;

  const StorageEditPage({
    super.key,
    this.storageKey,
    required this.storageType,
  });

  @override
  State<StorageEditPage> createState() => _StorageEditPageState();
}

class _StorageEditPageState extends State<StorageEditPage> {
  final _storageService = GetIt.I.get<StorageService>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _formData = _StorageFormData();
  late final List<StorageEditField> _fields;
  late Storage2 _storage;
  var _isLoading = false;
  var _success = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageKey == null || widget.storageKey!.isEmpty
        ? Storage2.create(widget.storageType)
        : _storageService.get(widget.storageKey!) ??
              Storage2.create(widget.storageType);
    _fields = _storage.editFields;
    _nameController.text = _storage.name;
    _keyController.text = _storage.key;
    _formData.init(_fields);
    if (_storage.storageType == .ftp &&
        _formData.controllers['port']?.text.isEmpty == true) {
      _formData.controllers['port']!.text = '21';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _formData.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _success = false;
    });
    _formData.save(_fields);
    _storage
      ..name = _nameController.text.trim()
      ..key = _keyController.text.trim();
    try {
      if (_storage.storageType == .jellyfin || _storage.storageType == .emby) {
        await _loginToMediaServer();
      }
      await _storageService.update(_storage);
      setState(() => _success = true);
      showToast(title: '媒体库保存成功');
    } catch (e) {
      showToast(level: 3, title: '媒体库保存失败', description: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginToMediaServer() async {
    final url = _formData.text('url');
    final username = _formData.text('account');
    final password = _formData.text('password');
    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      throw AppException('登录失败', '请填写完整的服务器地址、用户名和密码');
    }
    final api = await createStreamMediaExplorerProvider(
      _storage,
      validateCredentials: false,
    );
    if (api == null) throw AppException('登录失败', '不支持的媒体库类型');
    final dio = await api.getDio(url, validateCredentials: false);
    final user = await api.login(dio, username, password);
    api.dispose();
    (_storage as StreamStorage)
      ..token = user.token
      ..userId = user.userId;
  }

  Widget _field(StorageEditField field) => switch (field.type) {
    .text => _textField(field),
    .toggle => _toggleField(field),
    .select => _selectField(field),
  };

  Widget _textField(StorageEditField field) {
    final controller = _formData.controllers[field.key]!;
    final common = (
      control: FTextFieldControl.managed(controller: controller),
      label: Text(field.label),
      keyboardType: (field.number ? TextInputType.number : TextInputType.text),
      validator: (value) {
        if (field.required && (value?.trim().isEmpty ?? true)) {
          return '${field.label}不能为空';
        }
        return field.validator?.call(value);
      },
    );
    final child = field.obscureText
        ? FTextFormField.password(
            control: common.control,
            label: common.label,
            keyboardType: common.keyboardType,
            validator: common.validator,
          )
        : FTextFormField(
            control: common.control,
            label: common.label,
            keyboardType: common.keyboardType,
            validator: common.validator,
          );
    return _padding(child);
  }

  Widget _toggleField(StorageEditField field) {
    final value = _formData.values[field.key] as bool? ?? false;
    void update(bool value) =>
        setState(() => _formData.values[field.key] = value);
    return FItem(
      title: Text(field.label, style: context.theme.typography.body.md),
      suffix: Switch(value: value, onChanged: update),
      onPress: () => update(!value),
    );
  }

  Widget _selectField(StorageEditField field) {
    final options = field.options!;
    final value =
        _formData.values[field.key] as String? ?? options.values.first;
    final label = options.entries
        .firstWhere((entry) => entry.value == value)
        .key;
    return _padding(
      FSelectMenuTile.fromMap(
        options,
        selectControl: .lifted(
          value: {value},
          onChange: (value) {
            setState(() => _formData.values[field.key] = value.last);
          },
        ),
        title: Text(field.label),
        details: Text(label),
      ),
    );
  }

  Widget _padding(Widget child) =>
      Padding(padding: .symmetric(vertical: 6), child: child);

  Future<void> _pickFolder() async {
    final path = defaultTargetPlatform == .android
        ? await AndroidSaf.pickDirectory(
            AndroidSaf.isTreeUri((_storage as LocalStorage).url)
                ? (_storage as LocalStorage).url
                : null,
          )
        : await FilePicker.getDirectoryPath();
    if (path != null) _formData.controllers['url']!.text = path;
  }

  String? _validateKey(String? value) {
    final key = value?.trim() ?? '';
    if (key.isEmpty) return 'Key不能为空';
    if (_storageService.exists(key) && key != _storage.key) return 'Key已存在';
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(key) ? null : 'Key只允许字母和数字';
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: widget.storageType.label,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _padding(
              FTextFormField(
                control: .managed(controller: _nameController),
                label: const Text('名称'),
                autofocus: true,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? '名称不能为空' : null,
              ),
            ),
            _padding(
              FTextFormField(
                control: .managed(controller: _keyController),
                label: const Text('Key'),
                readOnly: _storage.key.isNotEmpty,
                hint: '用于标识，不可重复，只允许字母和数字',
                validator: _validateKey,
              ),
            ),
            ..._fields.map(_field),
            if (_storage.storageType == .local)
              _padding(
                FButton(
                  size: .lg,
                  onPress: _pickFolder,
                  child: const Text('选择文件夹'),
                ),
              ),
            _padding(
              FButton(
                size: .lg,
                prefix: _isLoading ? const FCircularProgress() : null,
                onPress: _isLoading ? null : _save,
                child: Text(_success ? '保存成功' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
