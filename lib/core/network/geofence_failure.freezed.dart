// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geofence_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GeofenceFailure {
  String get message => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) setupFailed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? setupFailed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? setupFailed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SetupFailed value) setupFailed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SetupFailed value)? setupFailed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SetupFailed value)? setupFailed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of GeofenceFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GeofenceFailureCopyWith<GeofenceFailure> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GeofenceFailureCopyWith<$Res> {
  factory $GeofenceFailureCopyWith(
    GeofenceFailure value,
    $Res Function(GeofenceFailure) then,
  ) = _$GeofenceFailureCopyWithImpl<$Res, GeofenceFailure>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class _$GeofenceFailureCopyWithImpl<$Res, $Val extends GeofenceFailure>
    implements $GeofenceFailureCopyWith<$Res> {
  _$GeofenceFailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GeofenceFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _value.copyWith(
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SetupFailedImplCopyWith<$Res>
    implements $GeofenceFailureCopyWith<$Res> {
  factory _$$SetupFailedImplCopyWith(
    _$SetupFailedImpl value,
    $Res Function(_$SetupFailedImpl) then,
  ) = __$$SetupFailedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$SetupFailedImplCopyWithImpl<$Res>
    extends _$GeofenceFailureCopyWithImpl<$Res, _$SetupFailedImpl>
    implements _$$SetupFailedImplCopyWith<$Res> {
  __$$SetupFailedImplCopyWithImpl(
    _$SetupFailedImpl _value,
    $Res Function(_$SetupFailedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GeofenceFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$SetupFailedImpl(
        null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SetupFailedImpl implements _SetupFailed {
  const _$SetupFailedImpl(this.message);

  @override
  final String message;

  @override
  String toString() {
    return 'GeofenceFailure.setupFailed(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetupFailedImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of GeofenceFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SetupFailedImplCopyWith<_$SetupFailedImpl> get copyWith =>
      __$$SetupFailedImplCopyWithImpl<_$SetupFailedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) setupFailed,
  }) {
    return setupFailed(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? setupFailed,
  }) {
    return setupFailed?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? setupFailed,
    required TResult orElse(),
  }) {
    if (setupFailed != null) {
      return setupFailed(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SetupFailed value) setupFailed,
  }) {
    return setupFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SetupFailed value)? setupFailed,
  }) {
    return setupFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SetupFailed value)? setupFailed,
    required TResult orElse(),
  }) {
    if (setupFailed != null) {
      return setupFailed(this);
    }
    return orElse();
  }
}

abstract class _SetupFailed implements GeofenceFailure {
  const factory _SetupFailed(final String message) = _$SetupFailedImpl;

  @override
  String get message;

  /// Create a copy of GeofenceFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SetupFailedImplCopyWith<_$SetupFailedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}







