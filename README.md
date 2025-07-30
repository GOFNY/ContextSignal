# 🔗 ContextSignal - Lightweight Event & Function System

A lightweight alternative to Roblox's `BindableEvent` and `BindableFunction`, offering better performance and a cleaner API.

This system is totally based on the [GoodSignal](https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f) implementation by [stravant](https://gist.github.com/stravant), with enhancements for typed Context-based access and session-safe invocation.

---

## 📊 Benchmark Comparison (Client, 1000 Calls)

| Type       | System            | Avg Latency (s) |
|------------|-------------------|-----------------|
| 🔁 Event   | BindableEvent     | `0.01063`       |
| 🔁 Event   | ContextSignal     | `0.00694`       |
| 🔧 Function| BindableFunction  | `0.00000`       |
| 🔧 Function| ContextSignal     | `0.00000`       |

### ✅ Notes:
- `ContextSignal` events are ~34% faster than `BindableEvent` based on average latency.
- Both function systems have near-zero latency under test conditions.
- `ContextSignal` is optimized for **lightweight performance** and **minimal memory overhead**, especially for high-frequency calls.

---

## 📘 API Reference

### 🔹 Function
A one-to-one callable system.

- `Invoke(...)`: Calls the `OnInvoke` function and returns its results.
- `OnInvoke`: A user-defined function that is triggered when `Invoke(...)` is used.

---

### 🔹 Connection
Object returned by `.Connect` or `.Once`.

- `Disconnect()`: Disconnects this specific listener from the event.

---

### 🔹 Event
Multi-listener signal for broadcasting.

- `Fire(...)`: Triggers the event, notifying all connected listeners.
- `Connect(fn)`: Connects a persistent listener function and returns a `Connection`.
- `Once(fn)`: Connects a one-time listener (auto-disconnects after being called once).
- `Wait()`: Yields until the next time the event is fired, returning the fired arguments.
- `DisconnectAll()`: Removes all listeners from the event.

---

### 🔹 ContextSignal
Central manager that creates and caches named Events/Functions.

- `GetFunction(Name: string)`: Returns (or creates) a `Function` by name.
- `GetEvent(Name: string)`: Returns (or creates) an `Event` by name.
- `GetAllFunctions()`: Returns a dictionary of all created `Functions`.
- `GetAllEvents()`: Returns a dictionary of all created `Events`.
- `GetAll()`: Returns a list with all `Functions` and `Events`.
