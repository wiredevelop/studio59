@if ($paginator->hasPages())
    @php
        $current = $paginator->currentPage();
        $last = $paginator->lastPage();
        $leadCount = 4;
    @endphp
    <nav role="navigation" aria-label="Pagination" class="flex items-center gap-1 text-sm">
        @if ($paginator->onFirstPage())
            <span class="px-3 py-1.5 rounded-full border border-white/20 text-gray-500 cursor-not-allowed">&lsaquo;</span>
        @else
            <a href="{{ $paginator->previousPageUrl() }}" rel="prev" class="px-3 py-1.5 rounded-full border border-white/30 hover:border-white/60">&lsaquo;</a>
        @endif

        @if ($last <= ($leadCount + 2))
            @for ($page = 1; $page <= $last; $page++)
                @if ($page === $current)
                    <span class="px-3 py-1.5 rounded-full border border-white/60 bg-white/10 text-white">{{ $page }}</span>
                @else
                    <a href="{{ $paginator->url($page) }}" class="px-3 py-1.5 rounded-full border border-white/30 hover:border-white/60">{{ $page }}</a>
                @endif
            @endfor
        @else
            @for ($page = 1; $page <= $leadCount; $page++)
                @if ($page === $current)
                    <span class="px-3 py-1.5 rounded-full border border-white/60 bg-white/10 text-white">{{ $page }}</span>
                @else
                    <a href="{{ $paginator->url($page) }}" class="px-3 py-1.5 rounded-full border border-white/30 hover:border-white/60">{{ $page }}</a>
                @endif
            @endfor

            <span class="px-3 py-1.5 rounded-full border border-white/20 text-gray-400">…</span>

            @for ($page = max($leadCount + 1, $last - 1); $page <= $last; $page++)
                @if ($page === $current)
                    <span class="px-3 py-1.5 rounded-full border border-white/60 bg-white/10 text-white">{{ $page }}</span>
                @else
                    <a href="{{ $paginator->url($page) }}" class="px-3 py-1.5 rounded-full border border-white/30 hover:border-white/60">{{ $page }}</a>
                @endif
            @endfor
        @endif

        @if ($paginator->hasMorePages())
            <a href="{{ $paginator->nextPageUrl() }}" rel="next" class="px-3 py-1.5 rounded-full border border-white/30 hover:border-white/60">&rsaquo;</a>
        @else
            <span class="px-3 py-1.5 rounded-full border border-white/20 text-gray-500 cursor-not-allowed">&rsaquo;</span>
        @endif
    </nav>
@endif
