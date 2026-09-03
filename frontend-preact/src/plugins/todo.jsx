import { useEffect, useRef, useState } from 'preact/hooks';
import {
  onHashChange,
  readHash,
  storageGet,
  storageSet,
  writeHash
} from './todo-storage.js';

const STORAGE_KEY = 'preact-todomvc.todos';
const FILTERS = ['all', 'active', 'completed'];

function createId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function readFilter() {
  const hashFilter = readHash().replace(/^#\/?/, '');
  return FILTERS.includes(hashFilter) ? hashFilter : 'all';
}

function loadTodos() {
  try {
    const savedTodos = JSON.parse(storageGet(STORAGE_KEY));
    if (!Array.isArray(savedTodos)) {
      return [];
    }

    return savedTodos.filter(
      (todo) =>
        todo &&
        typeof todo.id === 'string' &&
        typeof todo.title === 'string' &&
        typeof todo.completed === 'boolean'
    );
  } catch {
    return [];
  }
}

export function TodoApp() {
  const [todos, setTodos] = useState(loadTodos);
  const [newTodo, setNewTodo] = useState('');
  const [filter, setFilter] = useState(readFilter);
  const [editingId, setEditingId] = useState(null);
  const [editValue, setEditValue] = useState('');
  const editInputRef = useRef(null);
  const cancelEditRef = useRef(false);

  const activeCount = todos.reduce(
    (count, todo) => count + (todo.completed ? 0 : 1),
    0
  );
  const completedCount = todos.length - activeCount;
  const visibleTodos = todos.filter((todo) => {
    if (filter === 'active') return !todo.completed;
    if (filter === 'completed') return todo.completed;
    return true;
  });

  useEffect(() => {
    storageSet(STORAGE_KEY, JSON.stringify(todos));
  }, [todos]);

  useEffect(() => {
    const handleHashChange = () => setFilter(readFilter());
    return onHashChange(handleHashChange);
  }, []);

  useEffect(() => {
    if (editingId && editInputRef.current) {
      editInputRef.current.focus();
      editInputRef.current.select();
    }
  }, [editingId]);

  function addTodo(event) {
    event.preventDefault();
    const title = newTodo.trim();
    if (!title) return;

    setTodos((currentTodos) => [
      ...currentTodos,
      { id: createId(), title, completed: false }
    ]);
    setNewTodo('');
  }

  function toggleTodo(id) {
    setTodos((currentTodos) =>
      currentTodos.map((todo) =>
        todo.id === id ? { ...todo, completed: !todo.completed } : todo
      )
    );
  }

  function deleteTodo(id) {
    setTodos((currentTodos) => currentTodos.filter((todo) => todo.id !== id));
    if (editingId === id) setEditingId(null);
  }

  function toggleAll() {
    const shouldComplete = activeCount > 0;
    setTodos((currentTodos) =>
      currentTodos.map((todo) => ({ ...todo, completed: shouldComplete }))
    );
  }

  function beginEditing(todo) {
    cancelEditRef.current = false;
    setEditingId(todo.id);
    setEditValue(todo.title);
  }

  function cancelEditing() {
    cancelEditRef.current = true;
    setEditingId(null);
    setEditValue('');
  }

  function finishEditing(save) {
    if (!editingId) return;

    if (cancelEditRef.current) {
      cancelEditRef.current = false;
      setEditingId(null);
      setEditValue('');
      return;
    }

    const title = editValue.trim();

    if (save && title) {
      setTodos((currentTodos) =>
        currentTodos.map((todo) =>
          todo.id === editingId ? { ...todo, title } : todo
        )
      );
    } else if (save && !title) {
      deleteTodo(editingId);
    }

    setEditingId(null);
    setEditValue('');
  }

  function chooseFilter(nextFilter) {
    setFilter(nextFilter);
    writeHash(nextFilter === 'all' ? '#/' : `#/${nextFilter}`);
  }

  function clearCompleted() {
    setTodos((currentTodos) => currentTodos.filter((todo) => !todo.completed));
  }

  return (
    <main className="todo-shell min-h-screen w-full px-4 pb-10 pt-4 sm:px-5 sm:pt-6">
      <div className="mx-auto w-full max-w-xl">
        <header className="mb-4 flex items-end justify-between gap-4">
          <div>
            <p className="eyebrow mb-1 font-bold uppercase tracking-[0.2em]">
              Keep it light
            </p>
            <h1 className="text-4xl font-black lowercase leading-none tracking-[-0.06em] text-emerald-950 sm:text-5xl">
              todos
            </h1>
          </div>
          <p className="hidden max-w-[10rem] pb-1 text-right text-xs leading-5 text-emerald-900/60 sm:block">
            Capture what matters.
          </p>
        </header>

        <section
          className="todo-card overflow-hidden rounded-3xl bg-white shadow-[0_12px_40px_rgba(20,66,54,0.14)]"
          aria-label="Todo list"
        >
          <form
            className="new-todo-row flex items-center gap-2 border-b border-emerald-950/10 px-4 py-3"
            onSubmit={addTodo}
          >
            <button
              className="toggle-all shrink-0 text-2xl leading-none text-emerald-950/30 transition hover:text-emerald-950 disabled:cursor-default disabled:opacity-30"
              type="button"
              aria-label={
                activeCount > 0 ? 'Complete all todos' : 'Mark all todos active'
              }
              onClick={toggleAll}
              disabled={todos.length === 0}
            >
              ↓
            </button>
            <input
              className="new-todo min-w-0 flex-1 bg-transparent text-base text-emerald-950 outline-none placeholder:text-emerald-950/35"
              value={newTodo}
              onInput={(event) => setNewTodo(event.currentTarget.value)}
              placeholder="What needs doing?"
              aria-label="New todo"
              autoComplete="off"
            />
          </form>

          {todos.length > 0 && (
            <ul className="todo-list" aria-live="polite">
              {visibleTodos.map((todo) => (
                <li
                  className={`todo-item group border-b border-emerald-950/10 px-4 py-3 ${editingId === todo.id ? 'editing' : ''}`}
                  key={todo.id}
                >
                  {editingId === todo.id ? (
                    <input
                      className="edit w-full rounded-xl border-2 border-lime-400 bg-lime-50 px-4 py-3 text-lg text-emerald-950 outline-none sm:text-xl"
                      ref={editInputRef}
                      value={editValue}
                      onInput={(event) =>
                        setEditValue(event.currentTarget.value)
                      }
                      onBlur={() => finishEditing(true)}
                      onKeyDown={(event) => {
                        if (event.key === 'Enter') finishEditing(true);
                        if (event.key === 'Escape') {
                          cancelEditing();
                        }
                      }}
                      aria-label="Edit todo"
                    />
                  ) : (
                    <div className="view flex items-center gap-3">
                      <input
                        className="todo-checkbox peer h-6 w-6 shrink-0 cursor-pointer appearance-none rounded-full border-2 border-emerald-950/20 transition checked:border-emerald-700 checked:bg-emerald-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime-500"
                        id={`todo-${todo.id}`}
                        type="checkbox"
                        checked={todo.completed}
                        onChange={() => toggleTodo(todo.id)}
                      />
                      <label
                        className="todo-label min-w-0 flex-1 cursor-text break-words text-base leading-6 text-emerald-950 peer-checked:text-emerald-950/35 peer-checked:line-through"
                        htmlFor={`todo-${todo.id}`}
                        onDblClick={() => beginEditing(todo)}
                      >
                        {todo.title}
                      </label>
                      <button
                        className="destroy shrink-0 rounded-full bg-transparent px-2 py-1 text-xl font-normal leading-none text-emerald-950/30 opacity-0 transition hover:bg-rose-100 hover:text-rose-600 group-hover:opacity-100 focus-visible:opacity-100"
                        type="button"
                        onClick={() => deleteTodo(todo.id)}
                        aria-label={`Delete ${todo.title}`}
                      >
                        ×
                      </button>
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}

          {todos.length > 0 && (
            <footer className="flex flex-wrap items-center gap-2 px-4 py-3 text-sm text-emerald-950/60">
              <span className="mr-auto">
                <strong className="font-bold text-emerald-950">
                  {activeCount}
                </strong>{' '}
                {activeCount === 1 ? 'item' : 'items'} left
              </span>
              <nav
                className="flex items-center gap-1"
                aria-label="Todo filters"
              >
                {FILTERS.map((filterName) => (
                  <button
                    className={`rounded-lg bg-transparent px-3 py-1.5 font-semibold capitalize transition hover:bg-lime-100 ${filter === filterName ? 'bg-lime-100 text-emerald-950' : ''}`}
                    type="button"
                    onClick={() => chooseFilter(filterName)}
                    aria-current={filter === filterName ? 'page' : undefined}
                    key={filterName}
                  >
                    {filterName}
                  </button>
                ))}
              </nav>
              {completedCount > 0 ? (
                <button
                  className="self-start rounded-lg bg-transparent px-2 py-1.5 font-semibold text-emerald-950/60 transition hover:bg-rose-100 hover:text-rose-600 sm:self-auto"
                  type="button"
                  onClick={clearCompleted}
                >
                  Clear completed
                </button>
              ) : (
                <span
                  className="hidden min-w-[8.5rem] sm:block"
                  aria-hidden="true"
                />
              )}
            </footer>
          )}

          {todos.length > 0 && visibleTodos.length === 0 && (
            <p className="border-b border-emerald-950/10 px-5 py-10 text-center text-emerald-950/50 sm:px-7">
              Nothing here right now.
            </p>
          )}
        </section>

        <p className="mt-4 text-center text-[0.65rem] font-semibold uppercase tracking-[0.16em] text-emerald-950/40">
          Double-tap to edit
        </p>
      </div>
    </main>
  );
}
