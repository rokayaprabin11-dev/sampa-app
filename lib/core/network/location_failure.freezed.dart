// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LocationFailure {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() permissionDenied,
    required TResult Function(String message) serviceUnavailable,
    required TResult Function() positionNotFound,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? permissionDenied,
    TResult? Function(String message)? serviceUnavailable,
    TResult? Function()? positionNotFound,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? permissionDenied,
    TResult Function(String message)? serviceUnavailable,
    TResult Function()? positionNotFound,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_PermissionDenied value) permissionDenied,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
    required TResult Function(_PositionNotFound value) positionNotFound,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_PermissionDenied value)? permissionDenied,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult? Function(_PositionNotFound value)? positionNotFound,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_PermissionDenied value)? permissionDenied,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult Function(_PositionNotFound value)? positionNotFound,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationFailureCopyWith<$Res> {
  factory $LocationFailureCopyWith(
    LocationFailure value,
    $Res Function(LocationFailure) then,
  ) = _$LocationFailureCopyWithImpl<$Res, LocationFailure>;
}

/// @nodoc
class _$LocationFailureCopyWithImpl<$Res, $Val extends LocationFailure>
    implements $LocationFailureCopyWith<$Res> {
  _$LocationFailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$PermissionDeniedImplCopyWith<$Res> {
  factory _$$PermissionDeniedImplCopyWith(
    _$PermissionDeniedImpl value,
    $Res Function(_$PermissionDeniedImpl) then,
  ) = __$$PermissionDeniedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$PermissionDeniedImplCopyWithImpl<$Res>
    extends _$LocationFailureCopyWithImpl<$Res, _$PermissionDeniedImpl>
    implements _$$PermissionDeniedImplCopyWith<$Res> {
  __$$PermissionDeniedImplCopyWithImpl(
    _$PermissionDeniedImpl _value,
    $Res Function(_$PermissionDeniedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$PermissionDeniedImpl implements _PermissionDenied {
  const _$PermissionDeniedImpl();

  @override
  String toString() {
    return 'LocationFailure.permissionDenied()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$PermissionDeniedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() permissionDenied,
    required TResult Function(String message) serviceUnavailable,
    required TResult Function() positionNotFound,
  }) {
    return permissionDenied();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? permissionDenied,
    TResult? Function(String message)? serviceUnavailable,
    TResult? Function()? positionNotFound,
  }) {
    return permissionDenied?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? permissionDenied,
    TResult Function(String message)? serviceUnavailable,
    TResult Function()? positionNotFound,
    required TResult orElse(),
  }) {
    if (permissionDenied != null) {
      return permissionDenied();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_PermissionDenied value) permissionDenied,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
    required TResult Function(_PositionNotFound value) positionNotFound,
  }) {
    return permissionDenied(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_PermissionDenied value)? permissionDenied,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult? Function(_PositionNotFound value)? positionNotFound,
  }) {
    return permissionDenied?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_PermissionDenied value)? permissionDenied,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult Function(_PositionNotFound value)? positionNotFound,
    required TResult orElse(),
  }) {
    if (permissionDenied != null) {
      return permissionDenied(this);
    }
    return orElse();
  }
}

abstract class _PermissionDenied implements LocationFailure {
  const factory _PermissionDenied() = _$PermissionDeniedImpl;
}

/// @nodoc
abstract class _$$ServiceUnavailableImplCopyWith<$Res> {
  factory _$$ServiceUnavailableImplCopyWith(
    _$ServiceUnavailableImpl value,
    $Res Function(_$ServiceUnavailableImpl) then,
  ) = __$$ServiceUnavailableImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ServiceUnavailableImplCopyWithImpl<$Res>
    extends _$LocationFailureCopyWithImpl<$Res, _$ServiceUnavailableImpl>
    implements _$$ServiceUnavailableImplCopyWith<$Res> {
  __$$ServiceUnavailableImplCopyWithImpl(
    _$ServiceUnavailableImpl _value,
    $Res Function(_$ServiceUnavailableImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$ServiceUnavailableImpl(
        null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ServiceUnavailableImpl implements _ServiceUnavailable {
  const _$ServiceUnavailableImpl(this.message);

  @override
  final String message;

  @override
  String toString() {
    return 'LocationFailure.serviceUnavailable(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServiceUnavailableImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServiceUnavailableImplCopyWith<_$ServiceUnavailableImpl> get copyWith =>
      __$$ServiceUnavailableImplCopyWithImpl<_$ServiceUnavailableImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() permissionDenied,
    required TResult Function(String message) serviceUnavailable,
    required TResult Function() positionNotFound,
  }) {
    return serviceUnavailable(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? permissionDenied,
    TResult? Function(String message)? serviceUnavailable,
    TResult? Function()? positionNotFound,
  }) {
    return serviceUnavailable?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? permissionDenied,
    TResult Function(String message)? serviceUnavailable,
    TResult Function()? positionNotFound,
    required TResult orElse(),
  }) {
    if (serviceUnavailable != null) {
      return serviceUnavailable(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_PermissionDenied value) permissionDenied,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
    required TResult Function(_PositionNotFound value) positionNotFound,
  }) {
    return serviceUnavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_PermissionDenied value)? permissionDenied,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult? Function(_PositionNotFound value)? positionNotFound,
  }) {
    return serviceUnavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_PermissionDenied value)? permissionDenied,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult Function(_PositionNotFound value)? positionNotFound,
    required TResult orElse(),
  }) {
    if (serviceUnavailable != null) {
      return serviceUnavailable(this);
    }
    return orElse();
  }
}

abstract class _ServiceUnavailable implements LocationFailure {
  const factory _ServiceUnavailable(final String message) =
      _$ServiceUnavailableImpl;

  String get message;

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServiceUnavailableImplCopyWith<_$ServiceUnavailableImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PositionNotFoundImplCopyWith<$Res> {
  factory _$$PositionNotFoundImplCopyWith(
    _$PositionNotFoundImpl value,
    $Res Function(_$PositionNotFoundImpl) then,
  ) = __$$PositionNotFoundImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$PositionNotFoundImplCopyWithImpl<$Res>
    extends _$LocationFailureCopyWithImpl<$Res, _$PositionNotFoundImpl>
    implements _$$PositionNotFoundImplCopyWith<$Res> {
  __$$PositionNotFoundImplCopyWithImpl(
    _$PositionNotFoundImpl _value,
    $Res Function(_$PositionNotFoundImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationFailure
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$PositionNotFoundImpl implements _PositionNotFound {
  const _$PositionNotFoundImpl();

  @override
  String toString() {
    return 'LocationFailure.positionNotFound()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$PositionNotFoundImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() permissionDenied,
    required TResult Function(String message) serviceUnavailable,
    required TResult Function() positionNotFound,
  }) {
    return positionNotFound();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? permissionDenied,
    TResult? Function(String message)? serviceUnavailable,
    TResult? Function()? positionNotFound,
  }) {
    return positionNotFound?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? permissionDenied,
    TResult Function(String message)? serviceUnavailable,
    TResult Function()? positionNotFound,
    required TResult orElse(),
  }) {
    if (positionNotFound != null) {
      return positionNotFound();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_PermissionDenied value) permissionDenied,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
    required TResult Function(_PositionNotFound value) positionNotFound,
  }) {
    return positionNotFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_PermissionDenied value)? permissionDenied,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult? Function(_PositionNotFound value)? positionNotFound,
  }) {
    return positionNotFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_PermissionDenied value)? permissionDenied,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    TResult Function(_PositionNotFound value)? positionNotFound,
    required TResult orElse(),
  }) {
    if (positionNotFound != null) {
      return positionNotFound(this);
    }
    return orElse();
  }
}

abstract class _PositionNotFound implements LocationFailure {
  const factory _PositionNotFound() = _$PositionNotFoundImpl;
}







