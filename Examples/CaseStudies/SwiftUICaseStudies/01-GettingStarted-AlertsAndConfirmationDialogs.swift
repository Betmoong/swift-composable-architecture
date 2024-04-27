import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 내용은 Composable Architecture에서 알림과 확인 대화 상자를 최적으로 처리하는 방법을 보여줍니다.

  이 라이브러리는 AlertState와 ConfirmationDialogState 두 가지 타입을 제공하는데, 이는 알림이나 대화 상자의 상태와 행동에 대한 데이터 설명입니다. \
  이러한 타입은 리듀서에서 구성될 수 있어 알림이나 확인 대화 상자가 표시될지 여부를 제어할 수 있으며, \
  해당하는 뷰 모디파이어 alert(_:)과 confirmationDialog(_:)는 알림이나 대화 상자 도메인에 초점을 맞춘 스토어에 바인딩될 수 있어 \
  뷰에서 알림이나 대화 상자를 표시할 수 있습니다.

  이러한 타입을 사용하는 이점은 사용자가 애플리케이션에서 알림과 대화 상자와 상호작용하는 방법에 대한 완전한 테스트 커버리지를 얻을 수 있다는 것입니다.
  """

@Reducer
struct AlertAndConfirmationDialog {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
    var count = 0
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case alertButtonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case confirmationDialogButtonTapped

    @CasePathable
    enum Alert {
      case incrementButtonTapped
    }
    @CasePathable
    enum ConfirmationDialog {
      case incrementButtonTapped
      case decrementButtonTapped
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.incrementButtonTapped)),
        .confirmationDialog(.presented(.incrementButtonTapped)):
        state.alert = AlertState { TextState("Incremented!") }
        state.count += 1
        return .none

      case .alert:
        return .none

      case .alertButtonTapped:
        state.alert = AlertState {
          TextState("Alert!")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
          ButtonState(action: .incrementButtonTapped) {
            TextState("Increment")
          }
        } message: {
          TextState("This is an alert")
        }
        return .none

      case .confirmationDialog(.presented(.decrementButtonTapped)):
        state.alert = AlertState { TextState("Decremented!") }
        state.count -= 1
        return .none

      case .confirmationDialog:
        return .none

      case .confirmationDialogButtonTapped:
        state.confirmationDialog = ConfirmationDialogState {
          TextState("Confirmation dialog")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
          ButtonState(action: .incrementButtonTapped) {
            TextState("Increment")
          }
          ButtonState(action: .decrementButtonTapped) {
            TextState("Decrement")
          }
        } message: {
          TextState("This is a confirmation dialog.")
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }
}

struct AlertAndConfirmationDialogView: View {
  @Bindable var store: StoreOf<AlertAndConfirmationDialog>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Text("Count: \(store.count)")
      Button("Alert") { store.send(.alertButtonTapped) }
      Button("Confirmation Dialog") { store.send(.confirmationDialogButtonTapped) }
    }
    .navigationTitle("Alerts & Dialogs")
    .alert($store.scope(state: \.alert, action: \.alert))
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
  }
}

#Preview {
  NavigationStack {
    AlertAndConfirmationDialogView(
      store: Store(initialState: AlertAndConfirmationDialog.State()) {
        AlertAndConfirmationDialog()
      }
    )
  }
}
