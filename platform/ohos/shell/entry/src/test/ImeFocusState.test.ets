import { describe, it, expect } from '@ohos/hypium';
import { ImeFocusAction, ImeFocusState } from '../main/ets/common/ImeFocusState';

export default function imeFocusStateTest() {
  describe('ImeFocusStateTest', () => {
    it('attaches on the first focus request', 0, () => {
      const state = new ImeFocusState();
      const decision = state.request(true);
      expect(decision.action).assertEqual(ImeFocusAction.Attach);
      expect(decision.password).assertTrue();
      expect(state.isPending).assertTrue();
      expect(state.isAttached).assertFalse();
    });

    it('reuses an attached keyboard with the same type', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      expect(state.completeAttach(true)).assertEqual(undefined);
      const decision = state.request(true);
      expect(decision.action).assertEqual(ImeFocusAction.Reuse);
      expect(state.isAttached).assertTrue();
    });

    it('detaches before changing the keyboard type', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      state.completeAttach(true);
      const decision = state.request(false);
      expect(decision.action).assertEqual(ImeFocusAction.Detach);
      expect(state.completeDetach()).assertEqual(undefined);
      expect(state.isAttached).assertFalse();
    });

    it('queues the newest request during attach and replays it', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      const queued = state.request(false);
      expect(queued.action).assertEqual(ImeFocusAction.Queue);
      expect(state.completeAttach(true)).assertFalse();
      expect(state.isAttached).assertTrue();
    });

    it('queues the newest request during detach and replays it', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      state.completeAttach(true);
      state.request(false);
      const queued = state.request(true);
      expect(queued.action).assertEqual(ImeFocusAction.Queue);
      expect(state.completeDetach()).assertTrue();
      expect(state.isAttached).assertFalse();
    });

    it('returns the queued request after a failed transition', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      state.request(false);
      expect(state.fail()).assertFalse();
      expect(state.isPending).assertFalse();
      expect(state.isAttached).assertFalse();
    });

    it('resets all state', 0, () => {
      const state = new ImeFocusState();
      state.request(true);
      state.completeAttach(true);
      state.reset();
      expect(state.isAttached).assertFalse();
      expect(state.isPending).assertFalse();
      expect(state.request(true).action).assertEqual(ImeFocusAction.Attach);
    });
  });
}
