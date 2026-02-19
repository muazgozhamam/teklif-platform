'use client';

import React from 'react';

type CategoryNode = {
  pathKey: string;
  name: string;
  children?: CategoryNode[];
};

type Props = {
  value: string;
  onChange: (leafPathKey: string) => void;
};

function findPath(nodes: CategoryNode[], target: string): CategoryNode[] | null {
  for (const node of nodes) {
    if (node.pathKey === target) return [node];
    const children = Array.isArray(node.children) ? node.children : [];
    if (children.length) {
      const childPath = findPath(children, target);
      if (childPath) return [node, ...childPath];
    }
  }
  return null;
}

function descendToLeaf(node: CategoryNode): CategoryNode[] {
  const chain: CategoryNode[] = [node];
  let cursor = node;
  while (Array.isArray(cursor.children) && cursor.children.length > 0) {
    cursor = cursor.children[0];
    chain.push(cursor);
  }
  return chain;
}

export function CategoryCascader({ value, onChange }: Props) {
  const [tree, setTree] = React.useState<CategoryNode[]>([]);
  const [path, setPath] = React.useState<CategoryNode[]>([]);

  React.useEffect(() => {
    let alive = true;
    fetch('/api/public/listings/categories', { cache: 'no-store' })
      .then(async (res) => {
        if (!res.ok) throw new Error('Kategori ağacı alınamadı');
        return res.json();
      })
      .then((rows: CategoryNode[]) => {
        if (!alive) return;
        const nextTree = Array.isArray(rows) ? rows : [];
        setTree(nextTree);
        if (!nextTree.length) return;

        if (value) {
          const existing = findPath(nextTree, value);
          if (existing && existing.length > 0) {
            const leafChain = descendToLeaf(existing[existing.length - 1]);
            const merged = [...existing.slice(0, -1), ...leafChain];
            setPath(merged);
            onChange(merged[merged.length - 1].pathKey);
            return;
          }
        }

        const firstLeafPath = descendToLeaf(nextTree[0]);
        setPath(firstLeafPath);
        onChange(firstLeafPath[firstLeafPath.length - 1].pathKey);
      })
      .catch(() => {
        if (!alive) return;
        setTree([]);
        setPath([]);
      });
    return () => {
      alive = false;
    };
  }, [value, onChange]);

  function handleSelect(level: number, selectedPathKey: string) {
    const optionsAtLevel = level === 0 ? tree : path[level - 1]?.children || [];
    const selected = optionsAtLevel.find((x) => x.pathKey === selectedPathKey);
    if (!selected) return;
    const nextPath = [...path.slice(0, level), ...descendToLeaf(selected)];
    setPath(nextPath);
    onChange(nextPath[nextPath.length - 1].pathKey);
  }

  if (!tree.length) {
    return (
      <div className="rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm text-[var(--muted)]">
        Kategori ağacı yükleniyor...
      </div>
    );
  }

  const selects: Array<{ label: string; options: CategoryNode[]; selected: string }> = [];
  let options = tree;
  let level = 0;
  while (options.length > 0) {
    const selected = path[level]?.pathKey || options[0].pathKey;
    selects.push({
      label: level === 0 ? 'Ana Kategori' : level === 1 ? 'Kategori' : level === 2 ? 'İşlem Türü' : 'Alt Kategori',
      options,
      selected,
    });
    const selectedNode = options.find((x) => x.pathKey === selected);
    if (!selectedNode || !selectedNode.children || selectedNode.children.length === 0) break;
    options = selectedNode.children;
    level += 1;
  }

  return (
    <div className="grid gap-2">
      {selects.map((item, idx) => (
        <label key={`${idx}-${item.label}`} className="grid gap-1">
          <span className="text-xs text-[var(--muted)]">{item.label}</span>
          <select
            className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
            value={item.selected}
            onChange={(e) => handleSelect(idx, e.target.value)}
          >
            {item.options.map((opt) => (
              <option key={opt.pathKey} value={opt.pathKey}>
                {opt.name}
              </option>
            ))}
          </select>
        </label>
      ))}
    </div>
  );
}

