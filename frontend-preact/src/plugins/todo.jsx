import { useEffect, useRef, useState } from 'preact/hooks';
import { styles, sx } from '../stylex-styles.js';
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
    <main className={sx('todo-shell')}>
      <div className={sx('todo-container')}>
        <header className={sx('todo-header')}>
          <div>
            <p className={sx('eyebrow')}>Keep it light</p>
            <h1 className={sx('todo-title')}>todos</h1>
          </div>
          <p className={sx('todo-intro')}>Capture what matters.</p>
        </header>

        <section className={sx('todo-card')} aria-label="Todo list">
          <form className={sx('new-todo-row')} onSubmit={addTodo}>
            <button
              className={sx('toggle-all')}
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
              className={sx('new-todo')}
              value={newTodo}
              onInput={(event) => setNewTodo(event.currentTarget.value)}
              placeholder="What needs doing?"
              aria-label="New todo"
              autoComplete="off"
            />
          </form>

          {todos.length > 0 && (
            <ul className={sx('todo-list')} aria-live="polite">
              {visibleTodos.map((todo) => (
                <li className={sx('todo-item')} key={todo.id}>
                  {editingId === todo.id ? (
                    <input
                      className={sx('edit')}
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
                    <div className={sx('view')}>
                      <input
                        className={sx('todo-checkbox')}
                        id={`todo-${todo.id}`}
                        type="checkbox"
                        checked={todo.completed}
                        onChange={() => toggleTodo(todo.id)}
                      />
                      <label
                        className={sx(
                          'todo-label',
                          todo.completed && styles.todoCompleted
                        )}
                        htmlFor={`todo-${todo.id}`}
                        onDblClick={() => beginEditing(todo)}
                      >
                        {todo.title}
                      </label>
                      <button
                        className={sx('destroy')}
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
            <footer className={sx('todo-footer')}>
              <span className={sx('todo-count')}>
                <strong className={sx('todo-strong')}>{activeCount}</strong>{' '}
                {activeCount === 1 ? 'item' : 'items'} left
              </span>
              <nav className={sx('todo-filters')} aria-label="Todo filters">
                {FILTERS.map((filterName) => (
                  <button
                    className={sx(
                      'todo-filter',
                      filter === filterName && styles.todoFilterActive
                    )}
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
                  className={sx('clear-completed')}
                  type="button"
                  onClick={clearCompleted}
                >
                  Clear completed
                </button>
              ) : (
                <span className={sx('todo-spacer')} aria-hidden="true" />
              )}
            </footer>
          )}

          {todos.length > 0 && visibleTodos.length === 0 && (
            <p className={sx('todo-empty')}>Nothing here right now.</p>
          )}
        </section>

        <p className={sx('todo-hint')}>Double-tap to edit</p>
      </div>
    </main>
  );
}
