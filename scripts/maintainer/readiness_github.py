#!/usr/bin/env python3
"""Bounded GET-only GitHub evidence transport; fixtures never fall through to network."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import parse_qs, urlencode, urlsplit

from exact_head_readiness import NotReady, canonical, digest, now, read_json, require, write_new

MAX_BYTES = 16 * 1024 * 1024
# Full two-observation collections include retained history and native Hex audits.
# Keep the caller's shutdown window separate from these acquisition deadlines.
RUN_COLLECTION_SECONDS = 360
REMOTE_COLLECTION_SECONDS = 1200
COLLECTION_SHUTDOWN_SECONDS = 30


def json_bytes(raw):
    def unique(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate_json_key')
            result[key] = value
        return result
    try:
        return json.loads(raw, object_pairs_hook=unique,
                          parse_constant=lambda _: (_ for _ in ()).throw(NotReady('invalid_json')))
    except (ValueError, UnicodeError) as exc:
        raise NotReady('invalid_json') from exc


class GitHub:
    def __init__(self, repo, private, fixture=None, budget=180, max_calls=400):
        require(re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo), 'invalid_repository')
        self.repo, self.private = repo, Path(private)
        self.private.mkdir(mode=0o700, parents=True, exist_ok=True)
        require(type(max_calls) is int and 1<=max_calls<=3000, 'remote_call_limit_policy')
        self.max_calls=max_calls
        self.deadline = time.monotonic() + budget
        self.fixture = read_json(Path(fixture)/'responses.json') if fixture is not None else None
        require(fixture is None or isinstance(self.fixture,dict),'fixture_response_map_invalid')
        self.calls, self.counts = [], {}
        self.repo_id = None
        if self.fixture is None:
            try:
                result=subprocess.run(['gh','auth','status','--hostname','github.com'],stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL,timeout=15,check=False)
                require(result.returncode==0,'remote_unauthorized')
            except (OSError,subprocess.TimeoutExpired) as exc:
                raise NotReady('remote_unauthorized') from exc

    def path(self, suffix):
        return 'repos/' + self.repo + '/' + suffix

    def get(self, path, binary=False, limit=MAX_BYTES):
        # Every physical attempt uses the existing recorder and global budgets.
        # Only transient HTTP responses retry; absent visibility never becomes empty.
        for attempt in range(3):
            before = len(self.calls)
            try:
                return self._get_once(path, binary=binary, limit=limit)
            except NotReady as exc:
                transient = (str(exc) == 'remote_unavailable' and
                             len(self.calls) == before + 1 and
                             self.calls[-1]['status'] in (502, 503, 504) and
                             self.calls[-1]['headers'].get('x-ratelimit-remaining') != '0' and
                             'retry-after' not in self.calls[-1]['headers'])
                if not transient or attempt == 2:
                    raise
                delay = 2 ** attempt
                require(len(self.calls) < self.max_calls and
                        time.monotonic() + delay < self.deadline, 'remote_budget_exhausted')
                time.sleep(delay)

    def _get_once(self, path, binary=False, limit=MAX_BYTES):
        require(type(limit) is int and 0<limit<=256_000_000 and (binary or limit==MAX_BYTES), 'remote_limit_policy')
        require(time.monotonic() < self.deadline and len(self.calls) < self.max_calls, 'remote_budget_exhausted')
        require(not path.startswith('/') and not urlsplit(path).scheme and '\\' not in path,
                'unsafe_api_path')
        require(path.startswith('repos/'+self.repo+'/') or path == 'repos/'+self.repo or
                self.repo_id and path.startswith('repositories/'+str(self.repo_id)+'/'), 'foreign_api_path')
        if self.fixture is not None:
            entries = self.fixture.get(path)
            require(isinstance(entries, list) and entries, 'fixture_response_missing')
            index = self.counts.get(path, 0)
            response = entries[min(index, len(entries)-1)]
            self.counts[path] = index + 1
            headers = {k.lower(): str(v) for k,v in response.get('headers', {}).items()}
            status = response['status']
            raw = base64.b64decode(response['base64'], validate=True) if 'base64' in response else canonical(response.get('body'))
        else:
            try:
                # gh owns credentials/redirects. Headers are retained only in restricted storage.
                with __import__('tempfile').TemporaryFile() as stream:
                    child = subprocess.Popen(['gh','api','--hostname','github.com','--include','--method','GET',
                        '-H','Accept: application/vnd.github+json','-H','X-GitHub-Api-Version: 2022-11-28',path],
                        stdout=stream, stderr=subprocess.DEVNULL)
                    end = min(self.deadline, time.monotonic()+35)
                    while child.poll() is None:
                        require(stream.tell() <= limit, 'remote_response_limit')
                        if time.monotonic() >= end:
                            child.kill(); child.wait(); raise NotReady('remote_timeout')
                        time.sleep(0.03)
                    require(stream.tell() <= limit, 'remote_response_limit')
                    stream.seek(0); payload=stream.read(limit+1)
                # gh --include emits one final HTTP header block, followed by response bytes.
                match = re.match(rb'HTTP/[^\s]+ ([0-9]{3})[^\r\n]*\r?\n',payload)
                require(match is not None, 'remote_unavailable')
                separator = b'\r\n\r\n' if b'\r\n\r\n' in payload else b'\n\n'
                head, raw = payload.split(separator,1)
                status=int(match[1]); headers={}
                for line in head.splitlines()[1:]:
                    key, value=line.split(b':',1); key=key.decode().lower()
                    require(key not in headers or key == 'link', 'ambiguous_response_headers')
                    headers[key]=headers.get(key,'')+value.decode().strip()
            except NotReady:
                if 'child' in locals() and child.poll() is None:
                    child.kill(); child.wait()
                raise
            except (OSError, ValueError, UnicodeError) as exc:
                raise NotReady('remote_unavailable') from exc
        require(len(raw) <= limit, 'remote_response_limit')
        record={'path':path,'status':status,'headers':headers,'body_sha256':digest(raw),'observed_at':now()}
        self.calls.append(record)
        prefix=f'{len(self.calls):04d}'
        write_new(self.private/(prefix+'-response'),raw)
        write_new(self.private/(prefix+'-request.json'),record)
        if status == 401:
            raise NotReady('remote_unauthorized')
        if status in (403,429):
            raise NotReady('remote_rate_limited' if headers.get('x-ratelimit-remaining') == '0' or status == 429 else 'remote_forbidden')
        require(status == 200, 'remote_unavailable')
        return (raw if binary else json_bytes(raw)), headers

    def pages(self, suffix, key=None, cap=10000):
        path = self.path(suffix)
        first=urlsplit(path); filters=parse_qs(first.query)
        require(filters.get('per_page') == ['100'], 'pagination_policy')
        result=[]; seen=set(); total=None
        while path:
            require(path not in seen and len(seen)<100, 'pagination_loop_or_limit')
            seen.add(path); body,headers=self.get(path)
            values=body.get(key) if key and isinstance(body,dict) else body if not key else None
            require(isinstance(values,list) and len(values)<=100, 'incomplete_pages')
            if key:
                count=body.get('total_count')
                require(isinstance(count,int) and not isinstance(count,bool) and 0<=count<=cap, 'inventory_count_limit')
                total=count if total is None else total
                require(count == total, 'inventory_changed')
            result.extend(values); require(len(result)<=cap, 'inventory_count_limit')
            links=headers.get('link',''); nexts=re.findall(r'<([^>]+)>\s*;\s*rel="next"',links)
            require(len(nexts)<=1, 'ambiguous_next_page')
            if not nexts:
                # A full array page without a declared count needs a following page to prove exhaustion.
                require(key is not None or len(values)<100, 'pagination_exhaustion_unproved')
                break
            nxt=urlsplit(nexts[0])
            require(nxt.scheme=='https' and nxt.netloc=='api.github.com' and not nxt.fragment,
                    'foreign_next_page')
            path=nxt.path.lstrip('/') + ('?'+nxt.query if nxt.query else '')
            root_path=nxt.path.lstrip('/')
            valid_paths={first.path}
            if self.repo_id:
                valid_paths.add(first.path.replace('repos/'+self.repo,'repositories/'+str(self.repo_id),1))
            if key=='workflow_runs' and re.search(r'/actions/workflows/[^/]+/runs$',first.path):
                workflow_ids={v.get('workflow_id') for v in result if isinstance(v,dict)}
                require(len(workflow_ids)==1 and all(type(v) is int and v>0 for v in workflow_ids),'workflow_identity')
                numeric=re.sub(r'/actions/workflows/[^/]+/runs$', '/actions/workflows/'+str(next(iter(workflow_ids)))+'/runs', first.path)
                valid_paths.add(numeric)
                if self.repo_id:valid_paths.add(numeric.replace('repos/'+self.repo,'repositories/'+str(self.repo_id),1))
            require(root_path in valid_paths, 'foreign_next_page')
            query=parse_qs(nxt.query)
            cursor_keys={'page','before','after'}
            cursors=[k for k in cursor_keys if k in query]
            require({k:v for k,v in query.items() if k not in cursor_keys} == {k:v for k,v in filters.items() if k not in cursor_keys} and
                    len(cursors)==1 and len(query[cursors[0]])==1 and 0<len(query[cursors[0]][0])<=1024 and
                    (cursors[0]!='page' or query['page'][0].isdigit()), 'pagination_query_drift')
        require(total is None or len(result)==total, 'incomplete_pages')
        return result

    def contents(self, relative, subject):
        from urllib.parse import quote
        path=self.path('contents/'+quote(relative,safe='/')+'?ref='+subject)
        for attempt in range(3):
            body,headers=self.get(path)
            require(isinstance(body,dict) and body.get('type')=='file' and body.get('path')==relative and
                    body.get('encoding')=='base64' and type(body.get('size')) is int and
                    0<=body['size']<=MAX_BYTES and isinstance(body.get('sha'),str) and
                    re.fullmatch(r'[0-9a-f]{40}',body['sha']), 'subject_file_unavailable')
            try:
                raw=base64.b64decode(re.sub(r'\s','',body['content']),validate=True)
            except (KeyError,ValueError,TypeError) as exc:
                raise NotReady('subject_file_unavailable') from exc
            # Git's blob identity binds the complete decoded bytes, not just size.
            blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
            reason='subject_file_incomplete' if len(raw)!=body['size'] else 'subject_file_digest_mismatch'
            if len(raw)==body['size'] and blob==body['sha']:
                return raw
            # Reacquire the entire same-ref response. Every attempt is retained by
            # get() and consumes its existing deadline/call budget; never repair it.
            if attempt==2 or headers.get('x-ratelimit-remaining')=='0' or 'retry-after' in headers:
                raise NotReady(reason)
            delay=2**attempt
            require(len(self.calls)<self.max_calls and time.monotonic()+delay<self.deadline,
                    'remote_budget_exhausted')
            time.sleep(delay)
