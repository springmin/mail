// Pure IME focus/attach state machine. The ArkTS page owns the controller and
// file/UI APIs; this class only decides which transition to run and remembers
// the newest focus request that arrived while a transition was in flight.
export enum ImeFocusAction {
  Queue,
  Reuse,
  Detach,
  Attach,
}

export interface ImeFocusDecision {
  action: ImeFocusAction;
  password: boolean;
}

export class ImeFocusState {
  private attached: boolean = false;
  private pending: boolean = false;
  private currentPassword: boolean | undefined = undefined;
  private queuedPassword: boolean | undefined = undefined;

  request(password: boolean): ImeFocusDecision {
    if (this.pending) {
      this.queuedPassword = password;
      return { action: ImeFocusAction.Queue, password };
    }
    if (this.attached && this.currentPassword === password) {
      return { action: ImeFocusAction.Reuse, password };
    }
    this.pending = true;
    if (this.attached) {
      return { action: ImeFocusAction.Detach, password };
    }
    return { action: ImeFocusAction.Attach, password };
  }

  completeAttach(password: boolean): boolean | undefined {
    this.pending = false;
    this.attached = true;
    this.currentPassword = password;
    return this.takeQueued();
  }

  completeDetach(): boolean | undefined {
    this.pending = false;
    this.attached = false;
    this.currentPassword = undefined;
    return this.takeQueued();
  }

  fail(): boolean | undefined {
    this.pending = false;
    return this.takeQueued();
  }

  reset(): void {
    this.attached = false;
    this.pending = false;
    this.currentPassword = undefined;
    this.queuedPassword = undefined;
  }

  get isAttached(): boolean {
    return this.attached;
  }

  get isPending(): boolean {
    return this.pending;
  }

  private takeQueued(): boolean | undefined {
    const queued = this.queuedPassword;
    this.queuedPassword = undefined;
    return queued;
  }
}
