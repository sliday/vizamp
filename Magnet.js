.pragma library

function position(index,count,progress) {
    const u=(index+0.5+Math.sin(index*2.39996323)*0.1)/count
    if(progress<0)return u
    const p=Math.max(0,Math.min(1,progress)),d=u-p,radius=0.22
    return u+0.72*(p-u)*Math.exp(-d*d/(radius*radius))
}
function sample(values,fraction) {
    const at=Math.max(0,Math.min(values.length-1,fraction*(values.length-1)))
    const i=Math.floor(at),j=Math.min(values.length-1,i+1)
    return (values[i]||0)*(1-(at-i))+(values[j]||0)*(at-i)
}
