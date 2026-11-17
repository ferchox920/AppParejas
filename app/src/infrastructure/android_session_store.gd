class_name AndroidSessionStore
extends RefCounted

# Default scope stores the rotating refresh token. Other scopes use separate keys and files.
const PROVIDER := "AndroidKeyStore"
const IV_SIZE := 12
var _alias: String
var _file: JavaObject

func _init(project_url: String, account_id: String = "") -> void:
	_alias = "appparejas.session.v1." + project_url.sha256_text()
	if not account_id.is_empty():
		_alias = "appparejas.drafts.v1." + JSON.stringify([project_url, account_id]).sha256_text()
	var activity: JavaObject = Engine.get_singleton("AndroidRuntime").getActivity()
	var directory: JavaObject = activity.getNoBackupFilesDir()
	if JavaClassWrapper.get_exception() == null and directory != null:
		var file_class := JavaClassWrapper.wrap("java.io.File")
		var path: JavaObject = file_class.File(directory, _alias)
		if JavaClassWrapper.get_exception() == null and path != null:
			_file = JavaClassWrapper.wrap("android.util.AtomicFile").AtomicFile(path)

func _read_sealed() -> PackedByteArray:
	if _file == null: return PackedByteArray()
	var sealed: Variant = _file.readFully()
	if JavaClassWrapper.get_exception() != null or not sealed is PackedByteArray: return PackedByteArray()
	return sealed

func read_token() -> String:
	var sealed := _read_sealed()
	if sealed.size() <= IV_SIZE + 16: return ""
	var key := _key(false)
	if key == null: return ""
	var cipher := _cipher()
	if cipher == null: return ""
	var spec := JavaClassWrapper.wrap("javax.crypto.spec.GCMParameterSpec")
	var parameters: JavaObject = spec.GCMParameterSpec(128, sealed.slice(0, IV_SIZE))
	if JavaClassWrapper.get_exception() != null or parameters == null: return ""
	cipher.init(2, key, parameters) # DECRYPT_MODE
	if JavaClassWrapper.get_exception() != null: return ""
	var plaintext: Variant = cipher.doFinal(sealed.slice(IV_SIZE))
	if JavaClassWrapper.get_exception() != null or not plaintext is PackedByteArray: return ""
	return plaintext.get_string_from_utf8()

func write_token(token: String) -> bool:
	if _file == null: return false
	var key := _key(true)
	if key == null: return false
	var cipher := _cipher()
	if cipher == null: return false
	cipher.init(1, key) # ENCRYPT_MODE, random IV from Android Keystore
	if JavaClassWrapper.get_exception() != null: return false
	var iv: Variant = cipher.getIV()
	if JavaClassWrapper.get_exception() != null or not iv is PackedByteArray or iv.size() != IV_SIZE: return false
	var ciphertext: Variant = cipher.doFinal(token.to_utf8_buffer())
	if JavaClassWrapper.get_exception() != null or not ciphertext is PackedByteArray: return false
	var stream: JavaObject = _file.startWrite()
	if JavaClassWrapper.get_exception() != null or stream == null: return false
	stream.write(iv + ciphertext)
	if JavaClassWrapper.get_exception() != null:
		_file.failWrite(stream)
		return false
	_file.finishWrite(stream)
	# AtomicFile can report rename failures in the Android log without throwing.
	return JavaClassWrapper.get_exception() == null and _read_sealed() == iv + ciphertext

func clear() -> bool:
	if _file == null: return false
	var store := _keystore()
	var key_deleted := false
	if store != null:
		store.deleteEntry(_alias)
		key_deleted = JavaClassWrapper.get_exception() == null
	_file.delete()
	if key_deleted: return true
	if JavaClassWrapper.get_exception() != null: return false
	var base: JavaObject = _file.getBaseFile()
	if JavaClassWrapper.get_exception() != null or base == null: return false
	var exists: bool = base.exists()
	return JavaClassWrapper.get_exception() == null and not exists

func _keystore() -> JavaObject:
	var store: JavaObject = JavaClassWrapper.wrap("java.security.KeyStore").getInstance(PROVIDER)
	if JavaClassWrapper.get_exception() != null or store == null: return null
	store.load(null)
	if JavaClassWrapper.get_exception() != null: return null
	return store

func _key(create: bool) -> JavaObject:
	var store := _keystore()
	if store == null: return null
	var key: JavaObject = store.getKey(_alias, PackedByteArray())
	if JavaClassWrapper.get_exception() != null: return null
	if key != null or not create: return key
	var builder_class := JavaClassWrapper.wrap("android.security.keystore.KeyGenParameterSpec$Builder")
	var builder: JavaObject = builder_class.call("KeyGenParameterSpec$Builder", _alias, 3) # PURPOSE_ENCRYPT | PURPOSE_DECRYPT
	if JavaClassWrapper.get_exception() != null or builder == null: return null
	builder.setBlockModes(PackedStringArray(["GCM"]))
	if JavaClassWrapper.get_exception() != null: return null
	builder.setEncryptionPaddings(PackedStringArray(["NoPadding"]))
	if JavaClassWrapper.get_exception() != null: return null
	var parameters: JavaObject = builder.build()
	if JavaClassWrapper.get_exception() != null or parameters == null: return null
	var generator: JavaObject = JavaClassWrapper.wrap("javax.crypto.KeyGenerator").getInstance("AES", PROVIDER)
	if JavaClassWrapper.get_exception() != null or generator == null: return null
	generator.init(parameters)
	if JavaClassWrapper.get_exception() != null: return null
	key = generator.generateKey()
	if JavaClassWrapper.get_exception() != null: return null
	return key

func _cipher() -> JavaObject:
	var cipher: JavaObject = JavaClassWrapper.wrap("javax.crypto.Cipher").getInstance("AES/GCM/NoPadding")
	if JavaClassWrapper.get_exception() != null: return null
	return cipher
