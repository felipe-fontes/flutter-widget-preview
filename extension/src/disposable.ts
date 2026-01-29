export interface Disposable {
  dispose(): void | Promise<void>;
}

export class DisposableStore implements Disposable {
  private readonly disposables: Disposable[] = [];

  add<T extends Disposable>(value: T | undefined | null): T | undefined {
    if (!value) {
      return value ?? undefined;
    }
    this.disposables.push(value);
    return value;
  }

  async dispose(): Promise<void> {
    const items = this.disposables.splice(0, this.disposables.length);
    for (const item of items) {
      const result = item.dispose();
      if (result instanceof Promise) {
        await result;
      }
    }
  }
}

