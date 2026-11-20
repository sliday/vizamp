.pragma library
function failed(state,now) {
    const count=(state.failures||0)+1
    return {value:count>=3&&now-(state.lastGood||0)>=2500?{}:state.value,failures:count,lastGood:state.lastGood||0}
}
function accept(state,raw,now) {
    try {
        if(raw.length>8192)throw new Error('Oversized status')
        const info=JSON.parse(raw)
        if(typeof info.playing!=='boolean')throw new Error('Missing playback state')
        const text=(v,n)=>typeof v==='string'?v.slice(0,n):''
        return {value:{playing:info.playing,identity:text(info.identity,256),title:text(info.title,1024),artist:text(info.artist,1024)},failures:0,lastGood:now}
    } catch(e) {return failed(state,now)}
}
function label(info) {
    const title=info.title||'',artist=info.artist||''
    return title&&artist?title+' - '+artist:title||artist
}
