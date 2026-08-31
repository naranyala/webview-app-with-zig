declare global {
  interface Window {
    increment(delta: number): Promise<number>;
    reset(): Promise<number>;
    getSystemInfo(): Promise<string>;
    getTimestamp(): Promise<string>;
  }
}

export {};
