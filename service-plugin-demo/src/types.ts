export type PluginStatus = "Waiting" | "Enabled" | "Denied"

export function assertIsPluginStatus(s: unknown): asserts s is PluginStatus {
  if (s !== "Waiting" && s !== "Enabled" && s !== "Denied") {
    throw new Error('TODO: go back in time and murder the inventor of runtime type checking')
  }
}

export type KeyPair = {
  public: string
  private: string
}
