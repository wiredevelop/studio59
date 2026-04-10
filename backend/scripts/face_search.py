#!/usr/bin/env python3
import argparse
import json
import os
import sys
import pickle
from pathlib import Path
from contextlib import redirect_stdout

import cv2
import numpy as np
from insightface.app import FaceAnalysis


def load_index(path: Path):
    if path.exists():
        try:
            with path.open('rb') as f:
                return pickle.load(f)
        except Exception:
            return {}
    return {}


def save_index(path: Path, data: dict):
    tmp = path.with_suffix('.tmp')
    with tmp.open('wb') as f:
        pickle.dump(data, f)
    tmp.replace(path)


def get_faces(app: FaceAnalysis, img_path: str):
    img = cv2.imread(img_path)
    if img is None:
        return []
    with redirect_stdout(sys.stderr):
        return app.get(img)


def main():
    orig_stdout = sys.stdout
    sys.stdout = sys.stderr

    def out(payload):
        print(json.dumps(payload), file=orig_stdout, flush=True)

    parser = argparse.ArgumentParser()
    parser.add_argument('--event', required=True, type=int)
    parser.add_argument('--selfie', required=True)
    parser.add_argument('--photos', required=True)
    parser.add_argument('--index', required=True)
    parser.add_argument('--threshold', type=float, default=0.55)
    parser.add_argument('--max', type=int, default=200)
    args = parser.parse_args()

    photos_path = Path(args.photos)
    index_path = Path(args.index)

    if not photos_path.exists():
        out({'error': 'photos_file_not_found'})
        return 1

    try:
        photos = json.loads(photos_path.read_text())
    except Exception:
        out({'error': 'invalid_photos_json'})
        return 1

    if not photos:
        out({'suggested': []})
        return 0

    with redirect_stdout(sys.stderr):
        app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        app.prepare(ctx_id=0, det_size=(640, 640))

    faces = get_faces(app, args.selfie)
    if not faces:
        out({'error': 'no_face_detected'})
        return 1

    query_emb = faces[0].embedding.astype(np.float32)
    qnorm = np.linalg.norm(query_emb)
    if qnorm == 0:
        out({'error': 'invalid_embedding'})
        return 1
    query_emb = query_emb / qnorm

    index = load_index(index_path)
    index.setdefault('photos', {})

    embeddings = []
    photo_ids = []

    for item in photos:
        pid = str(item['id'])
        path = item['path']
        mtime = item.get('mtime')
        if not mtime:
            try:
                mtime = os.path.getmtime(path)
            except Exception:
                mtime = None

        entry = index['photos'].get(pid)
        needs_update = True
        if entry and entry.get('mtime') == mtime:
            needs_update = False

        if needs_update:
            faces = get_faces(app, path)
            emb_list = [f.embedding.astype(np.float32).tolist() for f in faces]
            index['photos'][pid] = {
                'mtime': mtime,
                'embeddings': emb_list,
            }

        for emb in index['photos'][pid].get('embeddings', []):
            emb_arr = np.asarray(emb, dtype=np.float32)
            norm = np.linalg.norm(emb_arr)
            if norm == 0:
                continue
            emb_arr = emb_arr / norm
            embeddings.append(emb_arr)
            photo_ids.append(int(pid))

    if embeddings:
        emb_matrix = np.vstack(embeddings)
        scores = emb_matrix @ query_emb
    else:
        scores = np.array([])

    best = {}
    for pid, score in zip(photo_ids, scores.tolist()):
        prev = best.get(pid)
        if prev is None or score > prev:
            best[pid] = score

    suggested = [
        {'id': pid, 'score': score}
        for pid, score in best.items()
        if score >= args.threshold
    ]
    suggested.sort(key=lambda x: x['score'], reverse=True)

    if args.max:
        suggested = suggested[: args.max]

    save_index(index_path, index)

    out({'suggested': suggested})
    return 0


if __name__ == '__main__':
    sys.exit(main())
