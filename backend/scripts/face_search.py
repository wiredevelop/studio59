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


def normalize_embedding(embedding):
    emb = np.asarray(embedding, dtype=np.float32)
    norm = np.linalg.norm(emb)
    if norm == 0:
        return None
    return emb / norm


def normalize_embeddings(embeddings):
    normalized = []
    for embedding in embeddings:
        emb = normalize_embedding(embedding)
        if emb is not None:
            normalized.append(emb)
    return normalized


def score_photo_matches(photo_embeddings, query_embeddings):
    if not photo_embeddings or not query_embeddings:
        return {}

    query_matrix = np.vstack(query_embeddings).T
    best = {}

    for pid, embeddings in photo_embeddings.items():
        if not embeddings:
            continue
        photo_matrix = np.vstack(embeddings)
        scores = photo_matrix @ query_matrix
        best[pid] = float(np.max(scores))

    return best


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

    query_embeddings = normalize_embeddings([face.embedding for face in faces])
    if not query_embeddings:
        out({'error': 'invalid_embedding'})
        return 1

    index = load_index(index_path)
    index.setdefault('photos', {})

    photo_embeddings = {}

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

        normalized_photo_embeddings = normalize_embeddings(
            index['photos'][pid].get('embeddings', [])
        )
        if normalized_photo_embeddings:
            photo_embeddings[int(pid)] = normalized_photo_embeddings

    best = score_photo_matches(photo_embeddings, query_embeddings)

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
