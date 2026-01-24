import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../domain/use_cases/home_use_cases.dart';
import '../../../domain/entities/home_entity.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends HydratedBloc<HomeEvent, HomeState> {
  final HomeUseCases _homeUseCases;

  HomeBloc({
    required HomeUseCases homeUseCases,
  }) : _homeUseCases = homeUseCases,
       super(const HomeState()) {
    on<_Initialized>(_onInitialized);
    on<_ResetSuccessAndErrorStatus>(_onResetSuccessAndErrorStatus);
  }

  void _onResetSuccessAndErrorStatus(
    _ResetSuccessAndErrorStatus event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      successStatus: event.successStatus ?? state.successStatus,
      errorStatus: event.errorStatus ?? state.errorStatus,
      failure: null,
    ));
  }

  Future<void> _onInitialized(_Initialized event, Emitter<HomeState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isGetItems: true),
      successStatus: state.successStatus.copyWith(getItems: false),
      errorStatus: state.errorStatus.copyWith(getItems: false),
      failure: null,
    ));
    
    final Either<Failure, List<HomeEntity>> result = await _homeUseCases.fetchData();
    
    result.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isGetItems: false),
          errorStatus: state.errorStatus.copyWith(getItems: true),
          failure: failure,
        ));
      },
      (List<HomeEntity> entities) {
        emit(state.copyWith(
          items: entities,
          status: state.status.copyWith(isGetItems: false),
          successStatus: state.successStatus.copyWith(getItems: true),
          failure: null,
        ));
      },
    );
  }

  @override
  HomeState? fromJson(Map<String, dynamic> json) => null;

  @override
  Map<String, dynamic>? toJson(HomeState state) => null;
}

