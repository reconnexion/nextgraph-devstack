export function checkEnvVar(name: string, what: string): void {
  if (process.env[name] === undefined) {
    console.error(`EnvVar ${name} is not defined. Set it to ${what}`)
    process.exit(1)
  } else {
    console.debug(`EnvVar ${name} is set to ${process.env[name]}`)
  }
}

export function unwrap<T>(v: T | undefined, msg = 'unexpected undefined'): T {
  if (v === undefined) throw new Error(msg);
  return v;
}
