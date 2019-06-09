module audio.vstnodes;

import mar.passfail;
import mar.arraybuilder;

import audio.inherits;
import audio.renderformat;
import audio.dag : AudioGenerator;
import audio.vst : AEffect, eff;

struct VstEffect
{

    mixin InheritBaseTemplate!AudioGenerator;
    AEffect* aeffect;
    size_t outputNodeCount;
    ArrayBuilder!(AudioGenerator!void*) inputs;

    void initialize(AEffect* aeffect)
    {
        base.mix = &VstEffect.mix;
        base.connectOutputNode = &VstEffect.connectOutputNode;
        base.disconnectOutputNode = &VstEffect.disconnectOutputNode;
        base.renderFinished = &VstEffect.renderFinished;

        this.outputNodeCount = 0;
        this.aeffect = aeffect;
    }

    static void mix(VstEffect* me, ubyte[] channels, RenderFormat.SamplePoint* buffer,
        const RenderFormat.SamplePoint* limit)
    {
        foreach (input; me.inputs.data)
        {
            input.mix(input, channels, buffer, limit);
        }
        //me.aeffect.process(me.aeffect, buffer, buffer, limit - buffer);
    }

    static passfail connectOutputNode(VstEffect* me, void* outputNode)
    {
        if (me.outputNodeCount == 0)
        {
            me.aeffect.dispatcher(me.aeffect, eff.mainsChanged, 0, 1, null, 0);
        }
        me.outputNodeCount++;
        foreach (input; me.inputs.data)
        {
            const result = input.connectOutputNode(input, outputNode);
            if (result.failed)
                return result;
        }
        return passfail.pass;
    }
    static passfail disconnectOutputNode(VstEffect* me, void* outputNode)
    {
        me.outputNodeCount--;
        if (me.outputNodeCount == 0)
        {
            me.aeffect.dispatcher(me.aeffect, eff.mainsChanged, 0, 0, null, 0);
        }
        foreach (input; me.inputs.data)
        {
            const result = input.disconnectOutputNode(input, outputNode);
            if (result.failed)
                return result;
        }
        return passfail.pass;
    }
    static void renderFinished(VstEffect* me, void* outputNode)
    {
        foreach (input; me.inputs.data)
        {
            input.renderFinished(input, outputNode);
        }
    }
}